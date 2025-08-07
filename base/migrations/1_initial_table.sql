CREATE DATABASE IF NOT EXISTS analytics;

CREATE TABLE IF NOT EXISTS analytics.events (
    site_id String,
    visitor_id String,
    session_id String,
    url String,
    referrer Nullable(String),
    user_agent String,
    device_type String,
    country Nullable(String),
    timestamp DateTime,
    date Date DEFAULT toDate(timestamp),
    -- Indexes for common query patterns
    INDEX visitor_idx visitor_id TYPE bloom_filter GRANULARITY 3,
    INDEX session_idx session_id TYPE bloom_filter GRANULARITY 3,
    INDEX site_idx site_id TYPE bloom_filter GRANULARITY 3,
    INDEX url_idx url TYPE bloom_filter GRANULARITY 3,
    INDEX country_idx country TYPE bloom_filter GRANULARITY 3,
    INDEX date_idx date TYPE minmax GRANULARITY 3,
    INDEX timestamp_idx timestamp TYPE minmax GRANULARITY 3
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(date)
ORDER BY (site_id, date, visitor_id, session_id, timestamp)
SETTINGS index_granularity = 8192,
    min_bytes_for_wide_part = 0,
    min_rows_for_wide_part = 0;

CREATE MATERIALIZED VIEW IF NOT EXISTS analytics.daily_page_views
ENGINE = SummingMergeTree()
PARTITION BY toYYYYMM(date)
ORDER BY (site_id, date, url)
AS SELECT
    site_id,
    date,
    url,
    count() as views
FROM analytics.events
GROUP BY site_id, date, url;

CREATE MATERIALIZED VIEW IF NOT EXISTS analytics.daily_unique_visitors
ENGINE = AggregatingMergeTree()
PARTITION BY toYYYYMM(date)
ORDER BY (site_id, date)
AS SELECT
    site_id,
    date,
    uniqState(visitor_id) as unique_visitors
FROM analytics.events
GROUP BY site_id, date;
