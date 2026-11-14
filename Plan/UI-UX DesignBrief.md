# UI-UX Design Brief: Dream Force

**Product:** Dream Force — personal focus planner and Android-only screen-time insight companion  
**Design direction:** Quiet Momentum  
**Primary reference:** `frontend_reference.html`  
**Platforms:** Android first; iOS shares the core experience except Android-only external-app screen-time features.

## Style

- **Mood:** Calm, clean, minimal, warm, focused, and quietly encouraging.
- **Personality:** A private daily planning tool — not a game, clinical dashboard, or social leaderboard.
- **Visual principles:** Generous breathing room, compact useful data, soft rounded surfaces, restrained color, and one clear primary action per screen.
- **Avoid:** Streak pressure, shame language, loud gradients, excessive celebration, decorative animation during a live timer, dense data tables, and color-only meaning.
- **Reference patterns:** GitHub contribution heatmap for annual balance visualization; Android/Material touch target expectations; iOS-style clarity and safe-area behavior. These are interaction and hierarchy references, not visual copies.
- **Responsive rule:** Phone-first at 320 logical pixels and above. Default design frame is 390 × 844. Content scrolls inside the screen; the bottom navigation always occupies its own safe-area-aware row.

## Color palette

### Light theme

| Role | Hex | Usage |
| --- | --- | --- |
| Primary / evergreen | `#256D5B` | Primary CTA, selected controls, FAB |
| Primary dark | `#174C3D` | Primary text accent, selected navigation label |
| Primary soft | `#DDEFE7` | Active pills, gentle success surfaces |
| Focus | `#176B55` | Focus phase, focus charts and progress |
| Rest | `#235C9B` | Rest phase and phase information |
| Background | `#F6F8F5` | Screen canvas |
| Surface | `#FFFFFF` | Cards, inputs, navigation bar |
| Subtle surface | `#EAF0EC` | Automatic-focus card, session note, inactive visual grouping |
| Text | `#17231F` | Primary headings and body text |
| Muted text | `#52615A` | Supporting text, labels, descriptions |
| Border | `#D8E1DC` | Cards, inputs, dividers |
| Warning | `#8A5A00` | Caution or planned-item status |
| Error | `#B42318` | Delete session, validation error, negative balance |
| Heatmap green | `#CCEBDC` → `#16845C` | Increasing positive Activity − Screen Time balance |
| Heatmap red | `#F5D4D1` → `#B42318` | Increasing negative Activity − Screen Time balance |
| Neutral heatmap | `#E3E8E5` | Balanced/no-delta day |

### Dark theme

| Role | Hex | Usage |
| --- | --- | --- |
| Background | `#101915` | Screen canvas |
| Surface | `#18221D` | Cards and bottom navigation |
| Subtle surface | `#23312A` | Secondary grouping surfaces |
| Text | `#F1F5F2` | Primary text |
| Muted text | `#BECBC3` | Supporting text |
| Primary / focus | `#77C6A7` | Actions and focus state |
| Rest | `#8DBBFA` | Rest state |
| Border | `#34433A` | Cards and dividers |
| Warning | `#F0C36A` | Warnings |
| Error | `#FF8A80` | Destructive/error actions |

Use semantic tokens in implementation; individual screens must not introduce unapproved one-off colors. Verify final foreground/background combinations meet WCAG 2.2 AA contrast targets.

## Typography

- **Font family:** Roboto first, then `SF Pro Text`, system UI, `Segoe UI`, and sans-serif fallbacks.
- **Heading font and size:** 25 px, 700 weight, 1.2 line height, slight negative tracking (`-0.025em`) for page titles.
- **Section heading:** 17 px, 700 weight, 1.3 line height.
- **Card heading:** 16 px, 700 weight.
- **Body:** 14 px, regular or medium weight, 1.45–1.55 line height.
- **Supporting text:** 12–13 px, muted color, 1.4–1.45 line height.
- **Navigation label:** 10 px, 600 weight; active item is 700 weight.
- **Overline/metadata:** 10–12 px, 700 weight, optional uppercase with modest letter spacing.
- **Timer value:** 42 px, 700 weight, tabular numerals where supported.
- **Numeric values:** Use tabular numerals in timers, durations, heatmap summaries, and charts to prevent visual jitter.

## Layout and spacing

- **Screen horizontal padding:** 20 px on the 390 px reference phone.
- **Status bar:** 42 px visual region.
- **Vertical rhythm:** 8 px base unit; common gaps are 8, 10, 12, 16, 20, and 24 px.
- **Card radius:** 16 px standard; 14 px compact controls; 999 px for pills; circular controls for avatar and steppers.
- **Bottom navigation:** 72 px plus safe-area inset. Never overlay content; center floating add button rises above it.
- **Tap targets:** Minimum 44 × 44 logical px for key controls; visual icons may be smaller within the target.
- **Motion:** 160–240 ms for ordinary interactions; respect reduced-motion settings. Timer state must remain understandable without animation.

## Components

### Buttons

- **Primary:** Full-width evergreen fill, white 700-weight label, 50 px minimum height, 17 px radius. Use for one decisive action: save activity, save review, sign in, pause/resume.
- **Secondary:** White/surface background, border, evergreen-dark text. Use for low-risk alternate actions.
- **Tonal:** Primary-soft background with evergreen-dark text. Use for gentle continuation such as Start another activity.
- **Text action:** Borderless evergreen text. Use within list rows and section headings.
- **Destructive:** Surface background, visible error-colored border/text. Label explicitly, e.g. **Delete session**. Always show confirmation before execution.
- **Floating action button:** 58 px evergreen circle with minimalist plus icon and surface-colored border. It is centered above bottom navigation and always opens **Choose activity**.
- **State rules:** Support default, pressed, focus-visible, disabled, loading, and error states. Disabled actions remain readable and explain why when it is not obvious.

### Inputs

- White/surface card with 1 px border and 16 px radius.
- Label is above the value in 12 px semibold muted text.
- Input content is 14 px primary text.
- Helper text is 11 px muted text below content.
- Error state adds error border, inline text error, and accessible association with the field.
- Native date/time controls are preferred where platform-native behavior helps.

### Cards

- Standard card: surface fill, 1 px border, 16 px radius, 12–15 px internal padding.
- Activity row: icon/color dot, flexible name and metadata, one explicit trailing action; avoid entire-card tap behavior when multiple controls exist.
- Subtle information card: subtle-surface fill, standard border, primary heading, muted explanatory copy. Use the same treatment for Automatic focus and rest and Session note.
- Summary card: primary-soft fill for reflection prompts and supportive summaries.

### Modals and bottom sheets

- Use sheets for short choices and confirmations, not long forms.
- 24 px top radius, semantic title, concise explanatory text, Cancel/close path, and clearly labeled action.
- Delete-session confirmation explains that the active timer will stop and elapsed time remains in private history as a cancelled session.

### Navigation

- Persistent navigation: Today, Plan, Insights, Profile.
- Use minimalist 16 px outline SVG icons: clock, calendar/grid, target/insights, and person.
- Active destination receives a primary-soft icon pill and primary-dark label.
- The centered floating + button sits in a visual notch/gap between Plan and Insights; it is not a fifth tab.
- Insights is the third destination; History is not a bottom-navigation screen.

### Charts and heatmap

- Donut chart uses stable colors for categories/apps across chart, list, and usage bar.
- Heatmap compares Activity − Screen Time, not a 24-hour allocation.
- Larger 9 px square cells with 2 px gap are horizontally touch-scrollable.
- Include horizontally scrollable year pills (current year back to `INSIGHTS_HEATMAP_EARLIEST_YEAR`, default 2019), horizontally scrollable quarter pills, month labels, diverging legend, selected-day card, and 2 × 2 KPI cards. Select the current quarter on load and omit weekday labels beside the grid.
- Heatmap includes text labels and legend; red/green never carry meaning alone.

## Screens

### Create account

- **Layout, top to bottom:** Status bar; short brand/value header; private-account reassurance; required Terms/Privacy acknowledgement; optional screen-time cloud-sync consent; Google sign-in button; disclosure copy.
- **Key elements:** Continue with Google; required Terms and Privacy checkbox; separate default-off screen-time sync checkbox naming uploaded fields and purpose.
- **Primary action:** Google sign-in only becomes available after the agreement is acknowledged.

### Today

- **Layout, top to bottom:** Date and short encouragement with avatar; Quick start two-column cards; Today’s plan list; supportive reflection card; bottom navigation/FAB.
- **Key elements:** 3–4 icon-led quick-start cards, See all, Edit plan, Start actions, Review today.
- **Visual emphasis:** Date and immediate next action, not productivity score or streak.

### Choose activity

- **Layout, top to bottom:** Title/subtitle; search input; Quick picks; Recent list; Create custom activity button.
- **Key elements:** Activity icon, title, total duration, “Automatic focus & rest,” and Choose action.
- **Empty state:** Starter templates plus Create custom activity CTA.

### Create activity

- **Layout, top to bottom:** Title; name field; icon picker; total-duration stepper; automatic focus/rest explanation; Save activity button.
- **Key elements:** User-selectable icon and total duration only. Do not show manual format, focus-duration, rest-duration, skip, or custom-cycle selectors.
- **Schedule preview:** Explain the calculated phases in plain language; 90 minutes explains two 40/5 cycles and a long-rest recommendation.

### Focus timer

- **Layout, top to bottom:** Activity title; phase and cycle chips; large countdown ring; next-phase note; primary Pause/Resume button; destructive Delete session button; timer persistence helper text.
- **Key elements:** Focus/rest is distinguished by label, icon/shape, and color.
- **Controls:** Do not show Skip phase or Finish now. Delete session opens a confirmation dialog.

### Session complete

- **Layout, top to bottom:** Completion title; supportive summary; local-notification confirmation note; actual focus/rest rows; Done; Start another activity.
- **Key elements:** Restrained success feedback rather than confetti or streak gamification.

### Weekly plan

- **Layout, top to bottom:** Week title/timezone; horizontal weekday selector; selected-day activity list; Add activity; bottom navigation/FAB.
- **Key elements:** Ordered rows show icon/dot, name, local time or Any time, total duration, and Start/Skip actions.
- **Wide layout:** A week-at-a-glance grid may replace the single-day list on tablet widths.

### Edit weekly plan

- **Layout, top to bottom:** Title with Done; plan summary; editable/reorderable rows; Add activity; Copy this day.
- **Key elements:** Reorder handles have accessible non-drag alternatives; edits are visibly separate from Start actions.

### Daily review

- **Layout, top to bottom:** Date; calm daily summary; mood chips; open text reflection field; optional reason tags; Save review.
- **Key elements:** Reflection remains optional and private. Copy is neutral and supports days with no completed activity.

### Insights: Activity

- **Layout, top to bottom:** Page title; Activity/Screen time segmented control; period picker; total summary; donut chart; heatmap with year/quarter controls; selected-day comparison; KPI grid; activity-category list.
- **Key elements:** Activity reflects completed Dream Force focus time only. The donut and category list show focus time grouped by activity category.
- **Interaction:** Changing period updates total/chart/list; heatmap remains on the selected calendar year. Tapping a day updates selected-day details. Red heatmap values indicate more Android screen time; green values indicate more Dream Force activity; neutral indicates equal or no difference.

### Insights: Screen time (Android only)

- **Layout, top to bottom:** Page title; segment control; period picker; account-sync control; screen-time total; donut chart; heatmap; selected-day comparison; all-app list; sync status and Manage Usage access action.
- **Key elements:** App icon/fallback, app name, duration, percentage, usage bar, update time, cloud-sync status, revoke-and-delete action.
- **Platform rule:** Do not render this view on iOS.

### Usage access explanation (Android only)

- **Layout, top to bottom:** Title; reassurance that core features work without permission; explanation of Android Usage Access and optional account sync as separate choices; current permission status; Open Settings and Not now actions.
- **Key elements:** No simulated Android permission dialog. Explicitly explain the Settings handoff.

### Profile and settings

- **Layout, top to bottom:** Profile identity row with Edit profile; Preferences group; Android-only group; Privacy and support group; bottom navigation/FAB.
- **Key elements:** Appearance, timezone/locale, automatic focus/rest explanation, phase notifications, Usage access, Privacy Policy, Terms, export, and help.

### Edit profile

- **Layout, top to bottom:** Title/Cancel; avatar and Change avatar; display name; read-only Google account; optional gender, date of birth, country, city, profession; timezone; Save profile.
- **Key elements:** Optional personal fields use clear labels and helper text. Email is read-only and not publicly shown.

### Legal and account-management screens

- **Layout, top to bottom:** Clear page title; readable body with generous line height; last-updated date where applicable; visible Back/Close action.
- **Key elements:** Privacy/Terms screens are read-only. Export and deletion screens clearly state consequences and confirmation requirements.

### Admin CRM dashboard

- **Layout, top to bottom:** Admin header/identity; horizontally scrollable CRM section pills (Overview, Tickets, Templates, Notify); Day/Week/Month/Year filter; 2 × 2 operational KPI grid; support queue; top performers; Top 10 Apps aggregate list; primary Create notification and secondary Manage global templates actions.
- **Key elements:** Admin uses the same quiet visual system but has no user bottom navigation or floating activity button. CRM rows show status, assignment, and safe aggregate metadata only.
- **Privacy boundaries:** Top performers use minimal pseudonymous identifiers in the default dashboard. Top 10 Apps explicitly labels data as opt-in aggregate. Do not show private profiles, daily-review text, individual app lists, or individual app timelines.

## Accessibility and content rules

- Every icon-only control has an accessible name.
- Respect system text scaling and maintain logical focus order.
- Timer phase transitions are announced politely for screen readers.
- Pair color with clear text, icons, or shape differences.
- Use plain, supportive language: “Saved on this device; sync pending,” not technical error codes in the main UI.
- Never show journal text, personal profile fields, or Android app usage on notifications or lock screens.
