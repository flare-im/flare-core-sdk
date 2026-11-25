import { describe, expect, it, vi } from "vitest";

import { WebProductionBridge } from "./webProductionBridge";

function storageHostStub() {
  return {
    loadSnapshot: async () => "{}",
    saveMessage: async () => {},
    saveConversation: async () => {},
    saveCursor: async () => {},
    commitOutgoing: async () => {},
    savePendingSend: async () => {},
    deleteMessage: async () => {},
    deleteConversation: async () => {},
    deletePendingSend: async () => {},
  };
}

/**
 * WASM 是单线程，串行执行是硬约束；但**排队顺序**不必是先来后到。
 *
 * 线上现象：打开会话时的历史回填走 view.timeline.load_older，一次几百条，
 * 把用户的第一次发送挡在后面——实测 Enter→上屏 1253ms，
 * 而链子空闲时同样的发送只要 52ms。
 */
describe("invoke 队列优先级", () => {
  /** 让每次 invoke 都卡住，直到测试放行，从而能观察排队顺序。 */
  function gatedBridge() {
    const started: string[] = [];
    const gates: Array<() => void> = [];
    const bridge = new WebProductionBridge({
      loadRuntime: async () => ({
        runtime: {
          invoke: vi.fn(async (op: string) => {
            started.push(op);
            await new Promise<void>((resolve) => gates.push(resolve));
            return JSON.stringify({ ok: true });
          }),
          setEventCallback: vi.fn(),
          setStorageHost: vi.fn(),
        } as never,
      }),
      createStorageHost: () => storageHostStub() as never,
    });
    return { bridge, started, gates };
  }

  const settle = () => new Promise((r) => setTimeout(r, 0));

  /**
   * 放行到全部结束。
   *
   * ⚠️ 不能只 `gates.forEach(g => g())`：那只释放**当时已存在**的门，
   * 而排在后面的调用是被放行之后才开始执行、才产生自己的门的 ——
   * 那些门没人放，`allSettled` 就永远挂着。这条用例最初就是这么写的，
   * 表现为 5 秒超时，看上去像产品挂了，实际是判据自己写错。
   */
  async function drain(gates: Array<() => void>, promises: Array<Promise<unknown>>) {
    for (let i = 0; i < 50; i += 1) {
      while (gates.length) gates.shift()?.();
      await settle();
      await settle();
      if (!gates.length) break;
    }
    await Promise.allSettled(promises);
  }

  it("交互操作插到排队中的后台批量读前面", async () => {
    const { bridge, started, gates } = gatedBridge();

    // 先占住执行权
    const first = bridge.invoke({ operation: "message.get" } as never, {}).catch(() => {});
    await settle();
    expect(started).toEqual(["message.get"]);

    // 再排两个后台批量读，然后排一个发送
    const bg1 = bridge.invoke({ operation: "view.timeline.load_older" } as never, {}).catch(() => {});
    const bg2 = bridge.invoke({ operation: "sync.messages" } as never, {}).catch(() => {});
    await settle();
    const send = bridge.invoke({ operation: "message.send" } as never, {}).catch(() => {});
    await settle();

    // 正在执行的不被打断
    expect(started).toEqual(["message.get"]);

    gates.shift()?.();
    await settle();
    await settle();

    // 关键：发送虽然最后入队，但必须先于两个后台批量读执行
    expect(started[1]).toBe("message.send");

    await drain(gates, [first, bg1, bg2, send]);
  });

  it("同为交互操作时保持先来后到", async () => {
    const { bridge, started, gates } = gatedBridge();
    const a = bridge.invoke({ operation: "message.get" } as never, {}).catch(() => {});
    await settle();
    const b = bridge.invoke({ operation: "message.send" } as never, {}).catch(() => {});
    const c = bridge.invoke({ operation: "message.recall" } as never, {}).catch(() => {});
    await settle();

    gates.shift()?.();
    await settle(); await settle();
    expect(started[1]).toBe("message.send");

    gates.shift()?.();
    await settle(); await settle();
    expect(started[2]).toBe("message.recall");

    await drain(gates, [a, b, c]);
  });

  it("mark_read 属于后台：不能挡在发送前面", async () => {
    // 实测打开 2 万条消息的会话，mark_read 单次约 990ms —— 是后台窗口里最大的一项。
    // 用户没有在等未读数更新，但它排在发送前面会实打实拖慢上屏。
    const { bridge, started, gates } = gatedBridge();
    const first = bridge.invoke({ operation: "message.get" } as never, {}).catch(() => {});
    await settle();
    const mark = bridge.invoke({ operation: "conversation.mark_read" } as never, {}).catch(() => {});
    await settle();
    const send = bridge.invoke({ operation: "message.send" } as never, {}).catch(() => {});
    await settle();

    gates.shift()?.();
    await settle(); await settle();
    expect(started[1]).toBe("message.send");

    await drain(gates, [first, mark, send]);
  });
});
