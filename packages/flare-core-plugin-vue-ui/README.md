# Core plugin Vue UI

The host owns session, directory, navigation and platform callbacks. Components
render the Core-resolved view with the shared `@flare-im/vue-ui` kit.

Set `CorePluginHost.detailPresentation` to `"page"` for responsive card details:
a side drawer on PC and a full screen on mobile. Omitting it preserves `"sheet"`.
This affects declarative details; bundle contributions retain their own host.

Detail refreshes keep previously loaded records and depth. A failed background
read exposes a retry above those records. A next-page failure has its own error
and completion signal so repeated identical failures can be retried without
settling an action or discarding the list. Hosts still own record merging;
read retries never replay a command.

Web 页面宿主可通过 `detailPresentation: "page"` 选择完整详情呈现；默认面板保持兼容。
详情刷新、分页与动作各自保留状态。读取失败继续显示记录，重试原读取；提交失败保留草稿，
由用户重新提交。资金动作和授权结果始终以 Core 服务返回为准。

`CorePluginPage.promptOnNavigate` is a trusted product policy for continuing an explicit page
action into a guarded native consent prompt. It names both the destination action and operation;
Core still resolves permissions, quotes, PIN verification and the final command. It runs once
after that navigation, never on mount, refresh, Back or bundle navigation. Missing actions,
additional forms/confirmations, owner changes and stale reads leave the normal page controls.
Cancellation and errors require an explicit retry. Never use this hook to commit without consent.
A page action's navigation may also name `run` itself (plugin-declared): the same once-after-landing
rule for any operation of the new page (`actions`, then `menuActions`) without a form, confirm or
`disabledReason`; the host policy wins when both name one.


### Host composition with kit components

`CorePluginPage.pageContent(page, view)` may return `{ component, actionIds }` for a trusted host component,
or `undefined` for the default document. The component receives the resolved page/view, busy/error/form-error
state, authorized member search and directory callbacks, `onRefresh`, `onBack`, and `onAction`.
Only declared, unguarded root actions in `actionIds` can use that callback. Other actions retain the kit's
confirmation/form/native renderer. The Core session still owns validation, capabilities, command execution,
continuations and settlement; rendering a component never invokes an action or payment.

Trusted content also receives `contentState`, a mutable UI-only record owned by its current navigation frame.
Use it for unfinished editor values when refresh or a child-page round trip remounts the component. Each frame
has separate memory. Reopening the root, changing the port/viewer, hiding the surface or destroying the host
discards that memory. It is not persisted and must not contain passwords, authorization, payment proofs or
command outcomes. Restored values still pass the original form validation and explicit user action; restoring
a draft never runs a command. Revalidate member selections against the current authorized choices.

The trusted host can supply `mapPageView(page, view)` to adapt presentation for a specific product page.
It must preserve the original page data, action definitions, confirmation requirements, row keys and bound inputs.
The original session continues to resolve and execute commands; the mapping must not manufacture availability or
invoke an action. Return the original view for unsupported projections so new plugin fields remain visible.


`CorePluginConsentList` waits for its port, shows loading/read retry through the kit and ignores stale reads after a port change or unmount. A failed revoke rejects the kit confirmation action so it stays open for retry/cancel; the grant is removed only after success. `texts.failed` is read-failure copy; optional `texts.revokeFailed` supplies specific revoke-failure copy (otherwise `failed` is used). The component does not reinterpret SDK authorization results.
