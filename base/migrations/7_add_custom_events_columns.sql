ALTER TABLE analytics.events
    ADD COLUMN IF NOT EXISTS event_type Enum8('pageview' = 1, 'custom' = 2),
    ADD COLUMN IF NOT EXISTS custom_event_name String DEFAULT '',
    ADD COLUMN IF NOT EXISTS custom_event_json String DEFAULT '{}';

ALTER TABLE analytics.events
    ADD INDEX event_type_idx event_type TYPE bloom_filter GRANULARITY 3,
    ADD INDEX custom_event_name_idx custom_event_name TYPE bloom_filter GRANULARITY 3;
 