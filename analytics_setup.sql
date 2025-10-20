-- Analytics table for NAEI Multi-Group Viewer
-- Run this in your Supabase SQL editor to create the analytics table

-- Drop existing views (in reverse order due to dependencies)
DROP VIEW IF EXISTS export_stats;
DROP VIEW IF EXISTS popular_groups;
DROP VIEW IF EXISTS popular_pollutants;
DROP VIEW IF EXISTS analytics_summary;

CREATE TABLE IF NOT EXISTS analytics_events (
  id BIGSERIAL PRIMARY KEY,
  session_id TEXT NOT NULL,
  user_fingerprint TEXT,
  event_type TEXT NOT NULL,
  event_data JSONB,
  timestamp TIMESTAMPTZ DEFAULT NOW(),
  user_agent TEXT,
  page_url TEXT,
  referrer TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_analytics_timestamp ON analytics_events(timestamp);
CREATE INDEX IF NOT EXISTS idx_analytics_event_type ON analytics_events(event_type);
CREATE INDEX IF NOT EXISTS idx_analytics_session ON analytics_events(session_id);
CREATE INDEX IF NOT EXISTS idx_analytics_user ON analytics_events(user_fingerprint);

-- Enable Row Level Security (RLS) for privacy
ALTER TABLE analytics_events ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Allow analytics inserts" ON analytics_events;
DROP POLICY IF EXISTS "Allow analytics reads" ON analytics_events;

-- Create a policy that allows inserts from your app
-- (adjust this based on your security needs)
CREATE POLICY "Allow analytics inserts" ON analytics_events
  FOR INSERT WITH CHECK (true);

-- Create a policy for reading analytics (restrict to admin users if needed)
CREATE POLICY "Allow analytics reads" ON analytics_events
  FOR SELECT USING (true);

-- Optional: Create a view for easier analytics queries
CREATE VIEW analytics_summary WITH (security_invoker = on) AS
SELECT 
  DATE(timestamp) as date,
  event_type,
  COUNT(*) as event_count,
  COUNT(DISTINCT session_id) as unique_sessions,
  COUNT(DISTINCT user_fingerprint) as unique_users
FROM analytics_events 
GROUP BY DATE(timestamp), event_type
ORDER BY date DESC, event_count DESC;

-- Popular pollutants view
CREATE VIEW popular_pollutants WITH (security_invoker = on) AS
SELECT 
  event_data->>'pollutant' as pollutant,
  COUNT(*) as views,
  COUNT(DISTINCT session_id) as unique_sessions,
  AVG((event_data->>'year_range')::int) as avg_year_range,
  DATE(MIN(timestamp)) as first_viewed,
  DATE(MAX(timestamp)) as last_viewed
FROM analytics_events 
WHERE event_type IN ('chart_view', 'data_export', 'chart_download')
  AND event_data->>'pollutant' IS NOT NULL
GROUP BY event_data->>'pollutant'
ORDER BY views DESC;

-- Popular groups view  
CREATE VIEW popular_groups WITH (security_invoker = on) AS
SELECT 
  jsonb_array_elements_text(event_data->'groups') as group_name,
  COUNT(*) as usage_count,
  COUNT(DISTINCT session_id) as unique_sessions
FROM analytics_events 
WHERE event_type IN ('chart_view', 'data_export', 'chart_download')
  AND event_data->'groups' IS NOT NULL
GROUP BY jsonb_array_elements_text(event_data->'groups')
ORDER BY usage_count DESC;

-- Export statistics view
CREATE VIEW export_stats WITH (security_invoker = on) AS
SELECT 
  event_data->>'format' as export_format,
  event_data->>'pollutant' as pollutant,
  COUNT(*) as download_count,
  COUNT(DISTINCT session_id) as unique_downloaders,
  AVG((event_data->>'groups_count')::int) as avg_groups_per_export,
  DATE(MAX(timestamp)) as last_download
FROM analytics_events 
WHERE event_type = 'data_export'
GROUP BY event_data->>'format', event_data->>'pollutant'
ORDER BY download_count DESC;

COMMENT ON TABLE analytics_events IS 'Usage analytics for NAEI Multi-Group Viewer';
COMMENT ON VIEW analytics_summary IS 'Daily summary of analytics events';
COMMENT ON VIEW popular_pollutants IS 'Most viewed/exported pollutants';  
COMMENT ON VIEW popular_groups IS 'Most used emission source groups';
COMMENT ON VIEW export_stats IS 'CSV/Excel download statistics';