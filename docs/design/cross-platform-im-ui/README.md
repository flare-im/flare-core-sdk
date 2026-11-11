# Flare IM Cross-Platform UI Design

This package defines one shared UI direction for:

- `../flare-core-examples/apps/flare-core-web-app`
- `../flare-core-examples/apps/flare-core-tauri-app`
- `../flare-core-examples/apps/flare-core-ios-app`
- `../flare-core-examples/apps/flare-core-flutter-app`
- `../flare-core-examples/apps/flare-core-android-app`

It is based on the current Vue shared IM UI, Flutter chat implementation, iOS SwiftUI design system, and Android Compose theme. The intent is to make every first-party example feel like the same production IM product while still adapting to each platform.

## Product Direction

Flare IM should feel calm, fast, and operationally clear. The examples are not marketing pages; they are production-grade SDK workbenches that demonstrate reliable messaging, message recovery, rich content, plugin capability, and cross-platform integration.

Audience:

- SDK integrators validating message lifecycle and capabilities.
- Product teams evaluating the UI contract before embedding Flare IM.
- QA and platform engineers testing large conversations, failed sends, sync, media, and plugin fallback.

Single job:

- Let a user scan conversations, send and recover messages, understand runtime state, and exercise SDK capabilities without hunting through hidden debug flows.

## Design Language

### Tokens

The existing token direction is retained but tightened so blue/purple stays an accent instead of flooding every surface.

| Role | Token | Light | Dark | Usage |
| --- | --- | --- | --- | --- |
| App canvas | `bg.app` | `#F7F8FB` | `#0E0F14` | Full window, timeline gutter |
| Surface | `bg.surface` | `#FFFFFF` | `#171923` | Nav, conversation list, composer |
| Surface alt | `bg.surfaceAlt` | `#F1F4F8` | `#222633` | Search, chips, inactive panels |
| Brand | `brand.primary` | `#6D5DF6` | `#A78BFA` | Primary command, read receipt, focus |
| Brand soft | `brand.soft` | `#EEF0FF` | `#2A2548` | Selected conversation, mention highlight |
| Link/action | `accent.link` | `#1A75D1` | `#64A8FF` | Secondary action, attachment status |
| Incoming | `message.incoming` | `#FFFFFF` | `#222633` | Peer text bubble |
| Outgoing | `message.outgoing` | `#6D5DF6` | `#8B5CF6` | Self text bubble |
| Plugin/card | `message.plugin` | `#F7F5FF` | `#28213A` | Task, vote, schedule, custom |
| Text primary | `text.primary` | `#111318` | `#F3F4F8` | Main labels and body |
| Text secondary | `text.secondary` | `#687080` | `#A8ADBA` | Previews, meta |
| Hairline | `border.hairline` | `#E6E9F0` | `#303545` | Dividers |
| Success | `state.success` | `#16A34A` | `#34D777` | Connected, delivered |
| Warning | `state.warning` | `#D97706` | `#F6B23C` | Reconnecting, partial sync |
| Danger | `state.danger` | `#EF4444` | `#F26666` | Failed send, destructive |

Typography:

- Display: system UI semibold, used only for screen titles and selected chat title.
- Body: system UI regular/medium for dense scanning.
- Utility: tabular numerals for unread counts, seq, timings, message operation metrics.
- No viewport-scaled text. Message body is 14-15 px desktop and 15-16 px mobile.

Radius:

- App chrome: 0-8 px.
- Repeated cards and message plugin blocks: 8 px.
- Bubbles: 12-16 px with grouped corners.
- Touch controls: pill radius only for icon buttons or chips.

Signature element:

- A thin timeline status rail appears only when it carries information: date boundary, unread anchor, sync gap, pinned jump, failed local message, or search result jump. It gives Flare a reliability-focused identity without adding decorative noise.

## Information Architecture

### Shared Model

All clients use the same conceptual hierarchy:

1. Global runtime shell
2. Conversation list
3. Chat workspace
4. Message timeline
5. Composer
6. Conversation details and plugin/capability panels
7. Diagnostics / SDK lab

### Desktop: Web, Flutter PC, Tauri

Desktop uses a persistent multi-pane layout:

```text
Nav rail | Conversation list | Chat workspace | Context panel
```

- Web and Flutter PC can collapse the context panel below medium widths.
- Tauri is pure PC and should default to a denser split layout with resizable conversation and context panels.
- Runtime connection state lives in the header and composer strip, not as a blocking modal.
- SDK lab and diagnostics remain discoverable from the nav rail or context panel.

### Mobile: Web, Flutter, iOS, Android

Mobile uses a single-pane stack:

```text
Conversation list -> Chat -> Details/Search/Actions as sheets
```

- Safe areas are mandatory.
- Composer is anchored above the keyboard and can grow to multiline.
- Message actions use long press plus an explicit overflow affordance for discoverability.
- Search, attachment, emoji, sticker, and plugin creation use bottom sheets that never cover the active input cursor.

## Component Contracts

### Runtime Shell

States:

- Connected: quiet green dot and no banner.
- Connecting: compact top strip with spinner and short message.
- Reconnecting: amber strip and composer hint, send allowed only if local queue supports it.
- Disconnected: red strip, composer disabled or queued-send mode explicit.
- SDK unavailable: permanent empty state with diagnostic action.

### Conversation List

Each item shows:

- Avatar or group stack.
- Title.
- Last message preview from typed content.
- Timestamp.
- Unread count, mention marker, draft marker, mute/pin indicators.
- Sending/failed marker when last local message is not stable.

Interactions:

- Click/tap opens chat.
- Desktop context menu: pin, mute, archive, mark read, delete.
- Mobile swipe: mute/read only; destructive actions stay in confirmation sheet.
- Search filters by all/text/media/file and preserves current chat.

### Chat Header

Desktop:

- Title, subtitle/presence, runtime dot.
- Search, pin, call/video, details, more.
- Multi-select mode replaces title with selected count and batch actions.

Mobile:

- Back, title, presence, call/search/more.
- Details and search open sheets.

### Message Timeline

Current implementation already has virtualization, scroll anchor preservation, older loading, unread/new message button, grouped sender display, and pinned/search locate. The design keeps those semantics.

Required states:

- Empty conversation.
- Loading initial history.
- Loading older history.
- History unavailable after sync hint.
- Message sync error with retry.
- New messages below while browsing old history.
- Unread anchor.
- Pinned message anchor.
- Search result highlight.
- Multi-select.

Message identity order remains:

```text
serverId -> clientMsgId -> seq -> timestamp fallback
```

### Composer

States:

- Empty.
- Focused.
- Multiline, max height before internal scroll.
- Sending.
- Offline / reconnecting / queued-send.
- Reply active.
- Edit active.
- Attachment active.
- Emoji/sticker panel open.
- Mention panel open.
- Permission denied.
- Plugin unavailable.

Rules:

- Tool row and text input are visually separate but in one composer surface.
- Attachment, emoji, sticker, voice, rich text, screenshot, and plugin actions are icon-first.
- Send button is always stable size.
- Mention/autocomplete panel is anchored above the input and does not cover the active line.
- Draft text survives conversation switching where SDK state exists.
- Failure is visible in both composer and failed message row.

## Message Display Matrix

| Type | Display | Operations |
| --- | --- | --- |
| Text | Readable bubble, CJK/emoji/code safe line wrapping, link preview optional | Copy, reply, forward, react, edit self, recall self, multi-select |
| Rich text | Structured blocks with inline code, list, quote, mention highlight | Copy plain text, reply, forward, react |
| Image | Chromeless preview, safe max size, footer time/status overlay | Preview, download/open folder, forward, react |
| Image group | 2-9 tile grid with stable aspect ratios | Preview tile, download all, forward |
| Video | Preview frame, play control, duration, upload/download state | Play, download/open folder |
| Audio | Waveform row, duration, playback state | Play/pause, transcribe placeholder, forward |
| File | Icon, file name, size, download state | Download/open folder, forward |
| Location | Map thumbnail, address, open action | Open, forward |
| Quote/reply | Top quote strip with sender and clipped preview; tap locates source | Locate, reply chain |
| Forward | Collapsed digest with count and source list | Expand preview, forward |
| Link card | Title, domain, thumbnail fallback | Open, copy link |
| Sticker/emoji pack | Render asset by token; unknown token falls back to readable label, never raw unreadable text | React, reply, forward |
| System/notification | Centered compact event row | No reaction, no destructive actions |
| Task/schedule/vote/announcement | Plugin card surface, typed status, fallback if plugin unavailable | Open plugin, forward, pin |
| Custom/thread | Info card fallback with content type and preview | Open plugin if available |
| Recalled | Muted row with actor-aware copy | None or delete self |
| Failed local | Original bubble remains, red status, retry/delete affordance | Retry, delete local, copy |

## Message Operation Model

Desktop:

- Hover toolbar: react, reply, forward, more.
- Right click or more button: full menu.
- Keyboard: focus message then Enter/Space opens menu; Escape exits mode.
- Multi-select toolbar pins to the bottom of timeline above composer.

Mobile:

- Long press opens action sheet.
- Visible overflow button remains on failed/media/plugin messages.
- Batch select uses bottom toolbar.

Operation availability:

- Self text sent/read: edit, recall, delete self.
- Self failed: retry, delete local, copy.
- Peer: reply, forward, react, copy, report only when product plugin provides it.
- Recalled/system: no reaction and no edit.
- Media not downloaded: download.
- Media downloaded on desktop: open folder.
- Plugin unavailable: view fallback, copy raw preview, install/enable plugin if market is available.

## Responsive Breakpoints

| Width | Layout |
| --- | --- |
| `< 640` | Mobile stack, one-handed composer, bottom sheets |
| `640-899` | Tablet split optional: list + chat, context as sheet |
| `900-1279` | Desktop compact: list + chat, context hidden by default |
| `1280-1599` | Desktop standard: rail + list + chat + context |
| `>= 1600` | Wide desktop: keep chat max readable width, expand details and diagnostics |

## Accessibility

- Every icon-only button needs an accessible label and tooltip on desktop.
- Touch targets are at least 44x44 px.
- Focus ring uses `brand.primary`, never only shadow.
- Message body contrast must be AA.
- Status is not color-only: failed/reconnecting/read states include text or icon shape.
- Reduced motion disables ambient transitions and keeps only necessary state changes.
- Timestamps use locale-aware formatting.
- CJK, Latin, emoji, inline code, long URL, and unknown token text must wrap without overflow.

## Platform Mapping

| Platform | Implementation target |
| --- | --- |
| Web | `@flare-im/vue-ui` tokens/components, responsive desktop/mobile |
| Tauri | Same Vue UI with denser desktop defaults, file open/download affordances enabled |
| Flutter | Map tokens to `FlareThemeTokens`, support mobile and desktop layout with shared state names |
| iOS | Map to `FlareDesign`, use native safe area, sheets, context menus |
| Android | Map to `FlareTheme`, Compose Material without dynamic color, native long press/actions |

## Artifact Files

- `prototype.html`: low-fidelity interaction prototype board.
- `visual-design.html`: high-fidelity design board.
- Generated screenshots:
  - `prototype.png`
  - `visual-design.png`

