# LifeSync

A cross-platform personal productivity dashboard built with Flutter. LifeSync brings your tasks, finances, goals, notes, calendar, and AI assistant into one unified command center.

---

## Features

### Dashboard
Central landing view with today's events, monthly spending/savings stats, pinned notes, upcoming deadlines (goals + events within 7 days), today's top 5 tasks, a task completion streak counter, and budget utilization bar.

### Tasks
Full CRUD with priority (high/medium/low), category (College/DSA/Project/Personal/Placement), recurring schedules (daily/weekly/monthly), "today's focus" pinning, and completion streak tracking. Filter by All/Today/Pending/Done.

### Calendar
Custom month-grid with color-coded events by type (Personal/Placement/Coding Practice). Quick navigation, type filters, and a monthly event summary.

### Finance
Income/expense tracking with multiple money sources (Cash, Bank accounts), source balance management, monthly spending charts, budget limits per category, SIP tracking, and savings pots with target progress bars. The finance screen is PIN-protected.

### Goals
Short-term and long-term goals with deadlines, progress sliders, sub-tasks, auto-completion on reaching 100%, and a celebration banner on completion.

### Notes
Rich notes with title, body, tags (DSA/Finance/College/Ideas/Personal), pin/unpin, search, and deletion.

### AI Assistant "Dash"
Chat interface powered by OpenAI GPT-4o-mini running on a Supabase Edge Function. Dash has full context of your tasks, transactions, goals, notes, events, and settings — it can answer questions and create new items (tasks, transactions, goals, notes, events) on your behalf.

### Settings
Profile management (name, monthly budget, finance PIN), notification toggles (budget exceeded, daily summary, weekly report), bank account/source management, and app preferences (font, language, currency, metric/imperial system).

### Multi-language
Built-in translations for English, Spanish, Hindi, French, and Japanese.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Frontend | Flutter / Dart |
| Backend | Supabase (PostgreSQL, Auth, Edge Functions) |
| AI | OpenAI GPT-4o-mini |
| Charts | fl_chart |
| Fonts | Google Fonts |
| Auth | Supabase Auth (anonymous sign-in) |

---

## Getting Started

### Prerequisites
- Flutter SDK (stable channel)
- A Supabase project
- An OpenAI API key

### Setup

1. **Clone the repo**
   ```sh
   git clone https://github.com/yourusername/lifesync.git
   cd lifesync
   ```

2. **Install dependencies**
   ```sh
   flutter pub get
   ```

3. **Configure Supabase**

   Create a Supabase project and run the schema from `supabase_schema.sql`. Set your Supabase URL and anon key in the app (see `lib/supabase/client.dart`).

4. **Deploy the Edge Function**

   ```sh
   cd supabase
   supabase functions deploy assistant
   ```

   Set your OpenAI API key as a secret:
   ```sh
   supabase secrets set OPENAI_API_KEY=your_key_here
   ```

5. **Run the app**
   ```sh
   flutter run
   ```

---

## Project Structure

```
lib/
├── main.dart                  # App entry point
├── models/                    # Data models
│   ├── task.dart
│   ├── transaction.dart
│   ├── note.dart
│   ├── goal.dart
│   ├── calendar_event.dart
│   ├── bank_account.dart
│   ├── savings_pot.dart
│   └── settings.dart
├── screens/                   # UI screens
│   ├── home_screen.dart
│   ├── tasks_screen.dart
│   ├── calendar_screen.dart
│   ├── finance_screen.dart
│   ├── goals_screen.dart
│   ├── notes_screen.dart
│   ├── chat_screen.dart
│   └── settings_screen.dart
├── supabase/
│   └── client.dart            # Supabase CRUD operations
├── theme/
│   ├── app_theme.dart         # Colors, theme data
│   └── app_settings.dart      # Global settings + translations
└── widgets/                   # Reusable widgets
    ├── pin_dialog.dart
    ├── modal_sheet.dart
    ├── empty_state.dart
    └── progress_bar.dart
```

---

## Database Schema

9 tables with row-level security: `tasks`, `transactions`, `banks`, `savings_pots`, `goals`, `goal_subtasks`, `notes`, `calendar_events`, and `user_settings`. See `supabase_schema.sql` for the full schema.

---

## Platforms

Android, iOS, Linux, and Web.
