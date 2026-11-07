import { describe, expect, it, vi } from "vitest";

import { followRecoveryLinks } from "./recoveryLinks";

function source(started: string[] | null = null) {
  let arrive: (urls: string[]) => void = () => undefined;
  return {
    arrive: (urls: string[]) => arrive(urls),
    getCurrent: vi.fn(async () => started),
    onOpenUrl: vi.fn(async (handler: (urls: string[]) => void) => {
      arrive = handler;
    }),
  };
}

describe("followRecoveryLinks", () => {
  it("hands over the link the app was started with", async () => {
    const onLink = vi.fn();

    await followRecoveryLinks(source(["flare-recover://v1?p=a&k=b&s=c"]), onLink);

    expect(onLink).toHaveBeenCalledWith("flare-recover://v1?p=a&k=b&s=c");
  });

  it("hands over links that arrive later, verbatim", async () => {
    const onLink = vi.fn();
    const links = source();

    await followRecoveryLinks(links, onLink);
    links.arrive(["FLARE-RECOVER://v1?p=a"]);

    expect(onLink).toHaveBeenCalledWith("FLARE-RECOVER://v1?p=a");
  });

  it("leaves other schemes alone", async () => {
    const onLink = vi.fn();
    const links = source(["https://example.com/"]);

    await followRecoveryLinks(links, onLink);
    links.arrive(["flare-other://x"]);

    expect(onLink).not.toHaveBeenCalled();
  });

  it("listens before it reads, so a link arriving in between is not lost", async () => {
    const links = source();
    const order: string[] = [];
    links.onOpenUrl.mockImplementation(async () => { order.push("listen"); });
    links.getCurrent.mockImplementation(async () => { order.push("read"); return null; });

    await followRecoveryLinks(links, () => undefined);

    expect(order).toEqual(["listen", "read"]);
  });
});
