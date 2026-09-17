# Walkthrough: Window Auto-Sizing & 15s Unattended Connection Countdown

We have completed the client-side implementation to resolve window spacing issues and add support for unattended 15-second auto-accept countdowns.

## Key Changes Made

### 1. Home Page Compact Layout & Window Sizing
- **[desktop_home_page.dart](file:///d:/Github/XsightDeskClient/flutter/lib/desktop/pages/desktop_home_page.dart)**:
  - Fixed left pane container width to `280.0` for single-column presentation.
  - Enabled dynamic `_updateWindowSize()` callbacks across rendering triggers so the application window automatically fits `getIncomingOnlyHomeSize()` without creating wide dark empty space to the right.
- **[desktop_tab_page.dart](file:///d:/Github/XsightDeskClient/flutter/lib/desktop/pages/desktop_tab_page.dart)**:
  - Enabled automatic resizing to `getIncomingOnlyHomeSize()` when selecting the **Home** tab and resizing to `getIncomingOnlySettingsSize()` when selecting **Settings**.

### 2. Client-Side Attended vs. Unattended Connection Mode & Timer
- **[server_model.dart](file:///d:/Github/XsightDeskClient/flutter/lib/models/server_model.dart)**:
  - Added `isUnattended` (bool) and `countdown` (int) fields to `Client` model with fallback parsing for incoming IPC/JSON connection payloads.
- **[server_page.dart](file:///d:/Github/XsightDeskClient/flutter/lib/desktop/pages/server_page.dart)**:
  - Converted `_CmControlPanel` into a `StatefulWidget` managing a 1-second periodic timer for incoming unattended access requests.
  - Added an auto-accept banner: *"Auto-accepting in X s unless declined."*
  - Automatically executes session approval (`handleAccept`) when the timer reaches 0.
  - Safely cancels the timer if the user manually accepts, declines, or cancels the request.

---

## Master / Support Side AI Prompt

To configure your Master / Support repository, give this prompt to the AI agent working on that codebase:

```markdown
### Task: Add Attended / Unattended Connection Mode Selection

Please modify the connection initiation logic on the Master/Support side to allow technicians to choose between **Attended Access** and **Unattended Access (15s Countdown)** when connecting to a client ID.

#### Requirements:
1. **UI Option**:
   - In the connection UI (e.g., `connection_page.dart` or connection dialog), add a connection mode toggle or dropdown next to the "Connect" button:
     - `Attended Access` (Default)
     - `Unattended Access (15s Countdown)`

2. **Payload / Connection Request Flag**:
   - When initiating a connection, include the selected mode in the session handshake parameter / connection options payload sent to the rendezvous/relay server and client FFI:
     - `unattended`: `true` (when Unattended mode is selected)
     - `countdown`: `15` (or custom countdown duration in seconds)

3. **FFI & Protocol Integration**:
   - Pass `unattended` and `countdown` fields through the native login request / connection request handler so the receiving client receives these JSON properties in the incoming client payload.
```

---

## Verification & Results
- Verified clean syntax and state management for client connection cards.
- Ensured countdown timers initialize and teardown safely upon accept or cancel action.
