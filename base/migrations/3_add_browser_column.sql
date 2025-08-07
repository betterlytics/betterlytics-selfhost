ALTER TABLE analytics.events
    ADD COLUMN IF NOT EXISTS browser String DEFAULT '';

ALTER TABLE analytics.events
    ADD INDEX browser_idx browser TYPE bloom_filter GRANULARITY 3;