import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

interface Action {
  type: string;
  data: Record<string, unknown>;
}

interface RequestBody {
  message: string;
  userId: string;
}

serve(async (req) => {
  const { message, userId }: RequestBody = await req.json();

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );

  const openAiKey = Deno.env.get('OPENAI_API_KEY');
  if (!openAiKey) {
    return new Response(JSON.stringify({ error: 'OPENAI_API_KEY not set' }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  // Fetch user data for context
  const [tasks, transactions, goals, notes, events, settings, banks, pots] = await Promise.all([
    supabase.from('tasks').select('text,done,priority,category,date').eq('user_id', userId).order('created_at', { ascending: false }).limit(20),
    supabase.from('transactions').select('type,amount,category,source,source_id,note,date').eq('user_id', userId).order('date', { ascending: false }).limit(20),
    supabase.from('goals').select('title,progress,deadline,completed,goal_type').eq('user_id', userId).order('created_at', { ascending: false }),
    supabase.from('notes').select('title,body,tags').eq('user_id', userId).order('created_at', { ascending: false }).limit(10),
    supabase.from('calendar_events').select('title,date,event_type').eq('user_id', userId).order('date', { ascending: true }).limit(20),
    supabase.from('user_settings').select('name,monthly_budget,budget_limits,sips').eq('user_id', userId).maybeSingle(),
    supabase.from('banks').select('name,account_number,balance').eq('user_id', userId),
    supabase.from('savings_pots').select('name,target_amount,saved_amount').eq('user_id', userId),
  ]);

  const systemPrompt = `You are a helpful AI assistant for a personal life dashboard.
Your name is Dash. Be concise, friendly, and use natural language.

The user's name is ${(settings.data as any)?.name || 'Darshan'}.

CURRENT DATA CONTEXT:

TASKS (pending/done):
${JSON.stringify(tasks.data || [], null, 2)}

TRANSACTIONS (recent — includes source field: cash/gmoney/bank/parents):
${JSON.stringify(transactions.data || [], null, 2)}

GOALS:
${JSON.stringify(goals.data || [], null, 2)}

NOTES:
${JSON.stringify(notes.data || [], null, 2)}

CALENDAR EVENTS:
${JSON.stringify(events.data || [], null, 2)}

SETTINGS:
${JSON.stringify(settings.data || {}, null, 2)}

BANK ACCOUNTS:
${JSON.stringify(banks.data || [], null, 2)}

SAVINGS POTS:
${JSON.stringify(pots.data || [], null, 2)}

CAPABILITIES:
1. Answer questions about any data — spending by source (cash/gmoney/bank), categories, savings pots, bank accounts
2. Create new items — respond with a JSON action block at the end of your message
3. Give suggestions and insights based on the data
4. Summarize activity — income vs expenses, net savings, budget health

When creating items, append a JSON block like this (and ONLY for create actions):
===ACTIONS===
[{"type": "create_task", "data": {"text": "Practice DSA", "priority": "high", "category": "DSA", "date": "2026-06-23"}}]
===END===

Available action types:
- create_task: text (required), priority (high/medium/low), category (College/DSA/Project/Personal/Placement), date (YYYY-MM-DD), recurring (daily/weekly/monthly/null)
- create_transaction: type (income/expense), amount (number), category (Food/Transport/College/Subscriptions/Entertainment/Savings/Investment/Other or for income: Salary/Freelance/Parents/Investment/Gift/Other), source (cash/gmoney/bank/parents), note, date (YYYY-MM-DD)
- create_goal: title (required), deadline (YYYY-MM-DD), goal_type (short-term/long-term)
- create_note: title (required), body, tags (array of DSA/Finance/College/Ideas/Personal)
- create_event: title (required), date (YYYY-MM-DD), event_type (Personal/Placement/Coding Practice), note

Finance sources available: cash (physical money), gmoney (Google Pay / digital wallet), bank (bank account — specify bank name), parents (income from parents). You can answer questions like "how much cash did I spend?" or "show me my bank transactions".

Respond naturally. If the user asks something that's not in the data, be helpful but honest.`;

  const openAiRes = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${openAiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: 'gpt-4o-mini',
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: message },
      ],
      temperature: 0.7,
      max_tokens: 1000,
    }),
  });

  const aiData = await openAiRes.json();
  const reply = aiData.choices?.[0]?.message?.content || 'Sorry, I couldn\'t process that.';

  // Parse actions from response
  const actions: Action[] = [];
  const actionMatch = reply.match(/===ACTIONS===\n([\s\S]*?)\n===END===/);
  if (actionMatch) {
    try {
      const parsed = JSON.parse(actionMatch[1]);
      if (Array.isArray(parsed)) actions.push(...parsed);
    } catch (_) {}
  }
  const cleanReply = reply.replace(/===ACTIONS===\n[\s\S]*?\n===END===/, '').trim();

  // Execute actions
  const results: string[] = [];
  for (const action of actions) {
    try {
      switch (action.type) {
        case 'create_task':
          await supabase.from('tasks').insert({
            user_id: userId,
            text: action.data.text,
            priority: action.data.priority || 'medium',
            category: action.data.category || 'Personal',
            date: action.data.date || new Date().toISOString().split('T')[0],
            recurring: action.data.recurring || null,
          });
          results.push(`Created task: ${action.data.text}`);
          break;
        case 'create_transaction':
          await supabase.from('transactions').insert({
            user_id: userId,
            type: action.data.type,
            amount: action.data.amount,
            category: action.data.category,
            source: action.data.source || 'cash',
            note: action.data.note || '',
            date: action.data.date || new Date().toISOString().split('T')[0],
          });
          results.push(`Added transaction: ${action.data.type === 'income' ? '+' : '-'}${action.data.amount}`);
          break;
        case 'create_goal':
          await supabase.from('goals').insert({
            user_id: userId,
            title: action.data.title,
            deadline: action.data.deadline || null,
            goal_type: action.data.goal_type || 'short-term',
          });
          results.push(`Created goal: ${action.data.title}`);
          break;
        case 'create_note':
          await supabase.from('notes').insert({
            user_id: userId,
            title: action.data.title,
            body: action.data.body || '',
            tags: action.data.tags || [],
          });
          results.push(`Saved note: ${action.data.title}`);
          break;
        case 'create_event':
          await supabase.from('calendar_events').insert({
            user_id: userId,
            title: action.data.title,
            date: action.data.date,
            event_type: action.data.event_type,
            note: action.data.note || '',
          });
          results.push(`Added event: ${action.data.title}`);
          break;
      }
    } catch (e: unknown) {
      results.push(`Failed to ${action.type}: ${e instanceof Error ? e.message : 'unknown error'}`);
    }
  }

  return new Response(JSON.stringify({ reply: cleanReply, actions: results, hasActions: results.length > 0 }), {
    headers: { 'Content-Type': 'application/json' },
  });
});
