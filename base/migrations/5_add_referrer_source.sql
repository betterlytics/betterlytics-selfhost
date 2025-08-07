ALTER TABLE analytics.events
    ADD COLUMN IF NOT EXISTS referrer_source String DEFAULT 'direct',
    ADD COLUMN IF NOT EXISTS referrer_source_name String DEFAULT '',
    ADD COLUMN IF NOT EXISTS referrer_search_term String DEFAULT '',
    ADD COLUMN IF NOT EXISTS referrer_url String DEFAULT '';

ALTER TABLE analytics.events
    ADD INDEX referrer_source_idx referrer_source TYPE bloom_filter GRANULARITY 3;