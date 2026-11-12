import { afterEach, describe, expect, it, vi } from 'vitest';
import {
  createTauriGeneratedFileSaver,
  MAX_TAURI_GENERATED_FILE_BYTES,
  type TauriGeneratedFileInvoker,
} from './generatedFileSave';

const token = '01234567-89ab-4cde-8f01-23456789abcd';
const path = `/app/cache/generated-files/generated-${token}.bin`;
const blob = () => new Blob([new Uint8Array([137, 80, 78, 71, 13, 10, 26, 10])], { type: 'image/png' });
const staged = () => ({ token, path, sizeBytes: 8 });
const saved = () => ({ path: '/Users/viewer/Downloads/flare-code.png', fileName: 'flare-code.png' });
function deferred<T>() {
  let resolve!: (value: T) => void;
  const promise = new Promise<T>(done => { resolve = done; });
  return { promise, resolve };
}
function fixture() {
  const native = vi.fn().mockImplementation(async (command: string) => command === 'sdk_stage_generated_file' ? staged() : true);
  const save = vi.fn().mockResolvedValue(saved());
  return { native, save, run: createTauriGeneratedFileSaver(save, { invoke: native as TauriGeneratedFileInvoker }) };
}

describe('Tauri generated file save', () => {
  afterEach(() => vi.restoreAllMocks());
  it('stages exact bytes, awaits the existing typed save, then cleans only its token', async () => {
    const f = fixture();
    await expect(f.run(blob(), 'flare-code.png')).resolves.toEqual(saved());
    expect(f.native.mock.calls[0]).toEqual(['sdk_stage_generated_file', { bytesBase64: 'iVBORw0KGgo=' }]);
    expect(f.save).toHaveBeenCalledExactlyOnceWith({ sourcePath: path, fileName: 'flare-code.png', downloadKey: `generated:${token}` });
    expect(f.native.mock.calls[1]).toEqual(['sdk_cleanup_generated_file', { token }]);
  });

  it('does not stage or save an already aborted operation', async () => {
    const f = fixture(); const abort = new AbortController(); abort.abort();
    await expect(f.run(blob(), 'flare-code.png', { signal: abort.signal })).rejects.toMatchObject({ name: 'AbortError' });
    expect(f.native).not.toHaveBeenCalled(); expect(f.save).not.toHaveBeenCalled();
  });

  it('cleans a staging response that arrives after cancellation without starting media save', async () => {
    const f = fixture(); const wait = deferred<unknown>(); const abort = new AbortController();
    f.native.mockImplementationOnce(() => wait.promise);
    const running = f.run(blob(), 'flare-code.png', { signal: abort.signal });
    await vi.waitFor(() => expect(f.native).toHaveBeenCalledTimes(1));
    abort.abort(); wait.resolve(staged());
    await expect(running).rejects.toMatchObject({ name: 'AbortError' });
    expect(f.save).not.toHaveBeenCalled();
    expect(f.native).toHaveBeenLastCalledWith('sdk_cleanup_generated_file', { token });
  });

  it('keeps the original save failure even if finally cleanup also fails', async () => {
    const f = fixture(); const failure = new Error('save failed'); f.save.mockRejectedValue(failure);
    const diagnostic = vi.spyOn(console, 'warn').mockImplementation(() => {});
    f.native.mockImplementation(async (command: string) => { if (command === 'sdk_stage_generated_file') return staged(); throw new Error('cleanup failed'); });
    await expect(f.run(blob(), 'flare-code.png')).rejects.toBe(failure);
    expect(f.native).toHaveBeenLastCalledWith('sdk_cleanup_generated_file', { token });
    expect(diagnostic).toHaveBeenCalledExactlyOnceWith('[Flare SDK] Generated file staging cleanup failed');
  });

  it('keeps a validated successful save when cleanup fails and emits only a fixed diagnostic', async () => {
    const f = fixture(); const result = saved(); f.save.mockResolvedValue(result);
    const diagnostic = vi.spyOn(console, 'warn').mockImplementation(() => {});
    f.native.mockImplementation(async (command: string) => {
      if (command === 'sdk_stage_generated_file') return staged();
      throw new Error(`private generated content ${path} ${token}`);
    });
    await expect(f.run(blob(), 'flare-code.png')).resolves.toBe(result);
    expect(diagnostic.mock.calls).toEqual([['[Flare SDK] Generated file staging cleanup failed']]);
  });

  it('keeps cancellation as the original error when cleanup fails', async () => {
    const f = fixture(); const wait = deferred<unknown>(); const abort = new AbortController();
    const diagnostic = vi.spyOn(console, 'warn').mockImplementation(() => {});
    f.native.mockImplementation(async (command: string) => {
      if (command === 'sdk_stage_generated_file') return wait.promise;
      throw new Error(`private cleanup ${token}`);
    });
    const running = f.run(blob(), 'flare-code.png', { signal: abort.signal });
    await vi.waitFor(() => expect(f.native).toHaveBeenCalledTimes(1));
    abort.abort(); wait.resolve(staged());
    await expect(running).rejects.toMatchObject({ name: 'AbortError' });
    expect(f.save).not.toHaveBeenCalled();
    expect(diagnostic.mock.calls).toEqual([['[Flare SDK] Generated file staging cleanup failed']]);
  });

  it.each(['relative/file.bin', '/cache/../foreign.bin', '/etc/passwd', 'file:///cache/file.bin'])('rejects an invalid staging path %s and cleans its valid token', async badPath => {
    const f = fixture(); f.native.mockResolvedValueOnce({ ...staged(), path: badPath });
    await expect(f.run(blob(), 'flare-code.png')).rejects.toThrow('staging');
    expect(f.save).not.toHaveBeenCalled(); expect(f.native).toHaveBeenLastCalledWith('sdk_cleanup_generated_file', { token });
  });

  it('does not pass an invalid native token to save or cleanup', async () => {
    const f = fixture(); f.native.mockResolvedValueOnce({ ...staged(), token: '../foreign' });
    await expect(f.run(blob(), 'flare-code.png')).rejects.toThrow('staging');
    expect(f.save).not.toHaveBeenCalled(); expect(f.native).toHaveBeenCalledTimes(1);
  });

  it.each(['', 'relative.png', path])('rejects a missing or non-destination result path %s', async resultPath => {
    const f = fixture(); f.save.mockResolvedValue({ path: resultPath });
    await expect(f.run(blob(), 'flare-code.png')).rejects.toThrow('saved file path');
    expect(f.native).toHaveBeenLastCalledWith('sdk_cleanup_generated_file', { token });
  });

  it('reports a staging failure without any alternate download or save attempt', async () => {
    const f = fixture(); const failure = new Error('native unavailable'); f.native.mockRejectedValue(failure);
    await expect(f.run(blob(), 'flare-code.png')).rejects.toBe(failure);
    expect(f.save).not.toHaveBeenCalled(); expect(f.native).toHaveBeenCalledTimes(1);
  });

  it('rejects oversized data before invoking native code', async () => {
    const f = fixture();
    await expect(f.run(new Blob([new Uint8Array(MAX_TAURI_GENERATED_FILE_BYTES + 1)]), 'large.png')).rejects.toThrow('too large');
    expect(f.native).not.toHaveBeenCalled(); expect(f.save).not.toHaveBeenCalled();
  });

  it('rejects a late save result after cancellation and still performs cleanup', async () => {
    const f = fixture(); const wait = deferred<unknown>(); const abort = new AbortController(); f.save.mockReturnValue(wait.promise);
    const running = f.run(blob(), 'flare-code.png', { signal: abort.signal });
    await vi.waitFor(() => expect(f.save).toHaveBeenCalledTimes(1)); abort.abort(); wait.resolve(saved());
    await expect(running).rejects.toMatchObject({ name: 'AbortError' });
    expect(f.save).toHaveBeenCalledTimes(1); expect(f.native).toHaveBeenLastCalledWith('sdk_cleanup_generated_file', { token });
  });
});
