/**
 * Shapes of the plugin views the Rust core resolves (flare-plugin-protocol `ResolvedPluginView`,
 * card protocol v2). Kits render them as given: every path is already read, every label
 * translated, every condition applied. Optional members are absent when empty, so a v1 card
 * (fields and actions only) keeps its exact v1 shape.
 */

export type PluginUiTone = "neutral" | "info" | "success" | "warning" | "danger";

/** A card or row action. Labels and `confirm` are translated; `hiddenWhen` is already applied. */
export interface PluginUiAction {
  id: string;
  label: string;
  target?: { kind: "operation"; operation: string } | { kind: "page"; page: string; pluginId?: string } | { kind: "native"; capability: string };
  input?: Record<string, string>;
  /** Ids of `inputs` the host collects first; their values go to `invokeAction` as `formValues`. */
  form?: string[];
  /** Ask before invoking. */
  confirm?: string;
  style?: "primary" | "danger";
  /** `menu`: listed in the view's `menuActions` (the card's overflow menu); absent: the button row. */
  placement?: "menu";
}

export interface PluginUiField { label: string; value: string }

export interface PluginUiTextBlock { kind: "text"; text: string; maxLines?: number; style: "body" | "title" | "secondary" }
export interface PluginUiFieldsBlock { kind: "fields"; fields: PluginUiField[] }
export interface PluginUiChoice {
  index: number;
  label: string;
  selected: boolean;
  /** Present while results are shown. */
  count?: number;
  /** 0..=100, rounded half up; present while results are shown. */
  percent?: number;
}
/** Options with counts. Submitting calls `invokeAction(…, action.id, { selection: [indices] })`. */
export interface PluginUiChoicesBlock {
  kind: "choices";
  options: PluginUiChoice[];
  multiple: boolean;
  /** The viewer has a selection. */
  voted: boolean;
  closed: boolean;
  /** Counts and percentages are present. */
  showResults: boolean;
  total?: number;
  inputName: string;
  /** A multiple choice's limit (1..= option count): stop further ticks at it. Absent: no limit. */
  maxSelections?: number;
  /** The submit action, while the viewer can choose (absent once closed or hidden). */
  action?: PluginUiAction;
}
/** The header of a group of entries ("Option A · 5 votes · 42%"); `percent` 0..=100 when `count` and `total` are known. */
export interface PluginUiEntryGroup { key: string; label: string; count?: number; total?: number; percent?: number }
/** An entry's or row's enumerated value as words and a tone (`valueLabels`), such as a ledger line's kind. */
export interface PluginUiBadge { text: string; tone: PluginUiTone }
/** `index` is 1-based; in a grouped block it counts within the group. `group` is on the first entry of each group. */
export interface PluginUiEntry { index: number; text: string; name?: string; userId?: string; group?: PluginUiEntryGroup; badge?: PluginUiBadge }
/**
 * `more`: the host offers "view all", which opens `detail` (see `PluginUiSession.detail`).
 * `numbered: false` shows no numbers. `grouped`: render one flat list with a header row before every
 * entry that has `group`.
 */
export interface PluginUiEntriesBlock { kind: "entries"; items: PluginUiEntry[]; numbered: boolean; total: number; more: boolean; emptyText?: string; grouped?: boolean }
export interface PluginUiPeopleGroup { label: string; userIds: string[]; count: number; tone?: PluginUiTone }
export interface PluginUiPeopleBlock { kind: "people"; groups: PluginUiPeopleGroup[] }
export interface PluginUiStatusBlock { kind: "status"; label?: string; text: string; tone: PluginUiTone }
export interface PluginUiProgressBlock { kind: "progress"; label?: string; value: number; total: number; percent: number }
/** Epoch milliseconds; the host formats them in the viewer's time zone and counts down when asked. */
export interface PluginUiTimeBlock { kind: "time"; label?: string; atMs: number; endMs?: number; countdown: boolean }
export interface PluginUiDividerBlock { kind: "divider" }
export interface PluginUiNoteBlock { kind: "note"; text: string; tone?: PluginUiTone }
export interface PluginUiRowsBlock {
  kind: "rows";
  source: string;
  columns: Array<{ label: string; format: "text" | "time" }>;
  rows: Array<{ key: string; cells: Array<{ text: string; timeMs?: number }>; actions: Array<{ id: string; input: Record<string, unknown> }>; detailInput?: Record<string, unknown>; badge?: PluginUiBadge }>;
  /** Ids of the view's `inputs` shown as filters; absent: every input is a filter. */
  filters?: string[];
  nextCursor?: string;
  actions: PluginUiAction[];
  emptyText?: string;
}
export type PluginUiBlock =
  | PluginUiTextBlock | PluginUiFieldsBlock | PluginUiChoicesBlock | PluginUiEntriesBlock | PluginUiPeopleBlock
  | PluginUiStatusBlock | PluginUiProgressBlock | PluginUiTimeBlock | PluginUiDividerBlock | PluginUiNoteBlock | PluginUiRowsBlock;

export type PluginUiInputKind = "text" | "textarea" | "password" | "number" | "toggle" | "select" | "datetime" | "options" | "members" | "file";
/** Stable completed private upload reference. Never a URL, grant or local path. */
export interface UiFileReference { fileId: string }
export interface PluginUiFileInput {
  accept: string[];
  /** Positive byte limit, at most 5 MiB. */
  maxBytes: number;
  upload: { prepareOperation: string; completeOperation: string; purpose: string };
}
export interface PluginUiInputShowWhen { field: string; anyOf: string[] }
/**
 * A form input, labels translated and `default` resolved from the card data. Submitted values:
 * text/textarea/password strings, number, toggle boolean, select a choice `value`, datetime epoch ms,
 * options an array of strings, members an array of user ids (the host provides the members).
 * Password inputs never prefill from `default` and must not enter durable command storage.
 */
export interface PluginUiInput {
  id: string;
  kind: PluginUiInputKind;
  label: string;
  required?: boolean;
  placeholder?: string;
  maxLength?: number;
  min?: number;
  max?: number;
  default?: unknown;
  choices?: Array<{ value: string; label: string }>;
  file?: PluginUiFileInput;
  /** Earlier unconditional Select in this action form. Hidden values are not
   * required or submitted. Controller value changes invalidate every dependent
   * value/upload, even if both old and new values leave the input visible.
   * Conditional defaults seed visible host state only, never submission fallback. */
  showWhen?: PluginUiInputShowWhen;
}

export type PluginFormIssue =
  | "required" | "unknown" | "invalidType" | "tooLong" | "outOfRange"
  | "notAChoice" | "tooFewItems" | "tooManyItems" | "invalidItem" | "duplicateItem";
/** One problem with a submitted form value; `input` is the input id (empty when the whole form is not an object). */
export interface PluginFormError { input: string; issue: PluginFormIssue }

/**
 * Why a view is inert (`available: false`), or `unbound_copy` for a read-only copy of a card
 * (`available: true`, without actions, menu, inputs, detail or block submits).
 */
export type PluginUnavailableReason =
  | "disabled" | "not_installed" | "no_permission" | "unsupported_platform"
  | "incompatible_version" | "catalog_unreachable" | "unbound_copy";

/** A resolved document: a card, a composer form, or a detail sheet. */
export interface PluginPresentation {
  presentation?: { renderer: string; props: Record<string, unknown>; actions: Record<string, string> };
  available: boolean;
  unavailableReason?: PluginUnavailableReason;
  title: string;
  fields: PluginUiField[];
  /** Button-row actions not owned by a block; block actions live in their block. */
  actions: PluginUiAction[];
  /** Actions of the overflow menu (⋯); absent when there are none. */
  menuActions?: PluginUiAction[];
  blocks?: PluginUiBlock[];
  /** All document inputs; an action's `form` lists the ones it collects. */
  inputs?: PluginUiInput[];
  /** The contribution declares a "view all" detail. */
  detail?: boolean;
}

/**
 * A detail sheet: a {@link PluginPresentation} plus, while a paged detail has more, the cursor of
 * its next page. Load more with `PluginUiSession.detail(..., { page: { cursor: view.nextCursor, previous: view } })`;
 * Core appends the page and returns the merged sheet. Re-read it with `{ refresh: view }`, which keeps
 * the pages it had loaded.
 */
export interface PluginDetailPresentation extends PluginPresentation {
  /** Cursor of the next page; absent on the last page and on a detail that does not page. */
  nextCursor?: string;
}

/** Paging options of `PluginUiSession.detail`. */
export interface PluginDetailPage {
  /** The shown sheet's `nextCursor`. */
  cursor: string;
  /** The sheet shown so far, as `detail` returned it; the page comes back appended to it. */
  previous: PluginDetailPresentation;
}

/**
 * A plugin page (a `page` contribution, such as a wallet): a {@link PluginDetailPresentation} plus
 * `data`, what it was resolved against, which a page action passes back. An unavailable page is
 * `{available: false, title: "", unavailableReason}`; the host keeps its own page title.
 */
export interface PluginPagePresentation extends PluginDetailPresentation {
  /** Host conversation context returned separately from plugin source data. */
  conversationId?: string;
  data?: Record<string, unknown>;
}

/** Paging options of `PluginUiSession.page`. */
export interface PluginPagePage {
  /** The shown page's `nextCursor`. */
  cursor: string;
  /** The page shown so far, as `page` returned it; the next page comes back appended to it. */
  previous: PluginPagePresentation;
}

/** A presentation for one stored message card. */
export interface PluginCardPresentation extends PluginPresentation {
  /** The payload merged with the message's shared and local state layers; only while `available`. */
  data?: Record<string, unknown>;
  /** Version of the local layer (the viewer's own results); 0 when the message has none. */
  stateVersion: number;
  /** Version of the shared layer Core publishes for the card's entity; absent when there is none. */
  sharedStateVersion?: number;
}

/** Outcome of a card action: the capability response, what a host target returned, or form problems. */
export type PluginActionOutcome =
  | { kind: "operation"; response: { success?: boolean; data?: unknown; error?: unknown } & Record<string, unknown> }
  | { kind: "host"; result: unknown }
  | { kind: "formErrors"; errors: PluginFormError[] };

const FORM_ISSUES: ReadonlySet<string> = new Set<PluginFormIssue>([
  "required", "unknown", "invalidType", "tooLong", "outOfRange", "notAChoice", "tooFewItems", "tooManyItems", "invalidItem", "duplicateItem",
]);

/** Core's form errors, leaving out anything malformed. */
export function pluginFormErrors(value: unknown): PluginFormError[] {
  if (!Array.isArray(value)) return [];
  return value.flatMap((entry) => {
    const error = entry as { input?: unknown; issue?: unknown } | null;
    return error && typeof error.input === "string" && typeof error.issue === "string" && FORM_ISSUES.has(error.issue)
      ? [{ input: error.input, issue: error.issue as PluginFormIssue }] : [];
  });
}

const UNAVAILABLE_REASONS: ReadonlySet<string> = new Set<PluginUnavailableReason>([
  "disabled", "not_installed", "no_permission", "unsupported_platform", "incompatible_version", "catalog_unreachable", "unbound_copy",
]);

/** The v2 members of a resolved view, copied only when present and well-typed. */
export function pluginViewExtras(view: Record<string, unknown>): Pick<PluginPresentation, "presentation" | "blocks" | "inputs" | "detail" | "menuActions" | "unavailableReason"> {
  const p = view.presentation as PluginPresentation["presentation"];
  return {
    ...(view.available === true && p && typeof p.renderer === "string" && p.props && typeof p.props === "object"
      && p.actions && typeof p.actions === "object" ? { presentation: p } : {}),
    ...(Array.isArray(view.blocks) && view.blocks.length ? { blocks: view.blocks as PluginUiBlock[] } : {}),
    ...(Array.isArray(view.inputs) && view.inputs.length ? { inputs: view.inputs as PluginUiInput[] } : {}),
    ...(view.detail === true ? { detail: true } : {}),
    ...(Array.isArray(view.menuActions) && view.menuActions.length ? { menuActions: view.menuActions as PluginUiAction[] } : {}),
    ...(typeof view.unavailableReason === "string" && UNAVAILABLE_REASONS.has(view.unavailableReason)
      ? { unavailableReason: view.unavailableReason as PluginUnavailableReason } : {}),
  };
}
