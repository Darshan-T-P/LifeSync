-- Run this in Supabase SQL Editor
-- First create the tables, then enable RLS

-- TASKS
CREATE TABLE tasks (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users NOT NULL,
  text TEXT NOT NULL,
  done BOOLEAN DEFAULT false,
  priority TEXT CHECK (priority IN ('high','medium','low')) DEFAULT 'medium',
  category TEXT CHECK (category IN ('College','DSA','Project','Personal','Placement')) DEFAULT 'Personal',
  recurring TEXT CHECK (recurring IN ('daily','weekly','monthly') OR recurring IS NULL),
  is_focus BOOLEAN DEFAULT false,
  date DATE DEFAULT CURRENT_DATE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  completed_dates DATE[] DEFAULT '{}'
);

-- TRANSACTIONS (updated with source tracking)
CREATE TABLE transactions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users NOT NULL,
  type TEXT CHECK (type IN ('income','expense')) NOT NULL,
  amount NUMERIC NOT NULL,
  category TEXT NOT NULL,
  source TEXT CHECK (source IN ('cash','bank','savings','parents','other')) DEFAULT 'cash',
  source_id UUID,
  note TEXT DEFAULT '',
  date DATE DEFAULT CURRENT_DATE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- SOURCES (cash, gmoney, banks)
CREATE TABLE banks (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users NOT NULL,
  name TEXT NOT NULL,
  account_number TEXT DEFAULT '',
  balance NUMERIC DEFAULT 0,
  source_type TEXT DEFAULT 'bank' CHECK (source_type IN ('cash','bank')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- SAVINGS POTS
CREATE TABLE savings_pots (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users NOT NULL,
  name TEXT NOT NULL,
  target_amount NUMERIC DEFAULT 0,
  saved_amount NUMERIC DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- GOALS
CREATE TABLE goals (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users NOT NULL,
  title TEXT NOT NULL,
  deadline DATE,
  progress INTEGER DEFAULT 0 CHECK (progress >= 0 AND progress <= 100),
  goal_type TEXT CHECK (goal_type IN ('short-term','long-term')) DEFAULT 'short-term',
  completed BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- GOAL SUBTASKS
CREATE TABLE goal_subtasks (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  goal_id UUID REFERENCES goals ON DELETE CASCADE NOT NULL,
  text TEXT NOT NULL,
  done BOOLEAN DEFAULT false
);

-- NOTES
CREATE TABLE notes (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users NOT NULL,
  title TEXT NOT NULL,
  body TEXT DEFAULT '',
  tags TEXT[] DEFAULT '{}',
  pinned BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- CALENDAR EVENTS
CREATE TABLE calendar_events (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users NOT NULL,
  title TEXT NOT NULL,
  date DATE NOT NULL,
  event_type TEXT CHECK (event_type IN ('Personal','Placement','Coding Practice')) NOT NULL,
  note TEXT DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- USER SETTINGS (updated)
CREATE TABLE user_settings (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users UNIQUE NOT NULL,
  name TEXT DEFAULT '',
  monthly_budget NUMERIC DEFAULT 0,
  pin TEXT DEFAULT '',
  notify_budget_exceeded BOOLEAN DEFAULT true,
  notify_daily_summary BOOLEAN DEFAULT false,
  notify_weekly_report BOOLEAN DEFAULT false,
  budget_limits JSONB DEFAULT '{}'
);

-- INDEXES
CREATE INDEX idx_tasks_user_date ON tasks(user_id, date);
CREATE INDEX idx_transactions_user_date ON transactions(user_id, date);
CREATE INDEX idx_banks_user ON banks(user_id);
CREATE INDEX idx_savings_pots_user ON savings_pots(user_id);
CREATE INDEX idx_goals_user ON goals(user_id);
CREATE INDEX idx_notes_user ON notes(user_id);
CREATE INDEX idx_calendar_events_user_date ON calendar_events(user_id, date);

-- ENABLE RLS
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE banks ENABLE ROW LEVEL SECURITY;
ALTER TABLE savings_pots ENABLE ROW LEVEL SECURITY;
ALTER TABLE goals ENABLE ROW LEVEL SECURITY;
ALTER TABLE goal_subtasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE calendar_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_settings ENABLE ROW LEVEL SECURITY;

-- RLS POLICIES
CREATE POLICY "users own their tasks" ON tasks
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "users own their transactions" ON transactions
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "users own their banks" ON banks
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "users own their savings pots" ON savings_pots
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "users own their goals" ON goals
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "users own their subtasks" ON goal_subtasks
  FOR ALL USING (auth.uid() IN (SELECT user_id FROM goals WHERE id = goal_id))
  WITH CHECK (auth.uid() IN (SELECT user_id FROM goals WHERE id = goal_id));
CREATE POLICY "users own their notes" ON notes
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "users own their events" ON calendar_events
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "users own their settings" ON user_settings
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
