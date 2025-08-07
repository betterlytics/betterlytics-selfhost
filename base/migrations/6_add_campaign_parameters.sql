ALTER TABLE analytics.events
    ADD COLUMN IF NOT EXISTS utm_source String DEFAULT '',
    ADD COLUMN IF NOT EXISTS utm_medium String DEFAULT '',
    ADD COLUMN IF NOT EXISTS utm_campaign String DEFAULT '',
    ADD COLUMN IF NOT EXISTS utm_term String DEFAULT '',
    ADD COLUMN IF NOT EXISTS utm_content String DEFAULT '';

ALTER TABLE analytics.events
    ADD INDEX utm_source_idx utm_source TYPE bloom_filter GRANULARITY 3,
    ADD INDEX utm_medium_idx utm_medium TYPE bloom_filter GRANULARITY 3,
    ADD INDEX utm_campaign_idx utm_campaign TYPE bloom_filter GRANULARITY 3; 