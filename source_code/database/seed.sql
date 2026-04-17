
INSERT INTO zone_risk_profiles (zone_name, risk_tier, historical_events_per_year, flood_prone, avg_annual_rainfall_mm, center_lat, center_lng) VALUES
  ('Velachery',       'high',     14, TRUE,  1400, 12.981500, 80.218000),
  ('Madipakkam',      'high',     12, TRUE,  1380, 12.962300, 80.198600),
  ('Tambaram',        'high',     11, TRUE,  1350, 12.924900, 80.100000),
  ('Adyar',           'standard',  8, FALSE, 1250, 13.006700, 80.256500),
  ('Mylapore',        'standard',  7, FALSE, 1200, 13.036800, 80.267600),
  ('T Nagar',         'low',       3, FALSE, 1080, 13.041800, 80.234100),
  ('Guindy',          'standard',  6, FALSE, 1150, 13.006700, 80.220600),
  ('Nungambakkam',    'low',       3, FALSE, 1050, 13.056900, 80.242500),
  ('Anna Nagar',      'low',       4, FALSE, 1060, 13.085000, 80.210100),
  ('Egmore',          'low',       3, FALSE, 1070, 13.073200, 80.260900),
  ('Kodambakkam',     'standard',  5, FALSE, 1120, 13.050000, 80.224000),
  ('Porur',           'high',     11, TRUE,  1300, 13.035600, 80.156900),
  ('Chromepet',       'standard',  6, FALSE, 1180, 12.951600, 80.141300),
  ('Sholinganallur',  'high',     12, TRUE,  1350, 12.901000, 80.227900),
  ('Perungudi',       'high',     10, TRUE,  1320, 12.964000, 80.243000),
  ('Thiruvanmiyur',   'standard',  7, FALSE, 1220, 12.983000, 80.264000)
ON CONFLICT (zone_name) DO NOTHING;

INSERT INTO workers (id, name, age, phone, partner_id, platform, zones, avg_weekly_earnings, avg_active_hours_per_week, risk_tier, upi_id, joined_date) VALUES
  ('w-001', 'Arjun Kumar',   27, '+91-9876543210', 'SWG-CHN-28491', 'swiggy',  ARRAY['Velachery', 'Adyar', 'Thiruvanmiyur'], 5250, 52, 'high',     'arjun.kumar@okicici', '2024-03-15'),
  ('w-002', 'Priya Devi',    24, '+91-9123456780', 'SWG-CHN-31205', 'swiggy',  ARRAY['Nungambakkam', 'T Nagar'],              4800, 48, 'low',      'priya.d@okaxis',      '2024-06-01'),
  ('w-003', 'Ravi Shankar',  32, '+91-9988776655', 'SWG-CHN-19834', 'swiggy',  ARRAY['Velachery', 'Sholinganallur', 'Porur'], 5800, 58, 'high',     'ravi.s@oksbi',        '2023-11-20')
ON CONFLICT (id) DO NOTHING;

INSERT INTO policies (id, worker_id, status, weekly_premium, risk_tier, start_date, zones, next_debit_date, total_premiums_paid, weeks_active) VALUES
  ('pol-001', 'w-001', 'active', 69, 'high',     '2025-09-29', ARRAY['Velachery', 'Adyar', 'Thiruvanmiyur'], '2026-04-07', 1656, 24),
  ('pol-002', 'w-002', 'active', 29, 'low',      '2025-11-10', ARRAY['Nungambakkam', 'T Nagar'],              '2026-04-07',  551, 19),
  ('pol-003', 'w-003', 'active', 69, 'high',     '2025-08-04', ARRAY['Velachery', 'Sholinganallur', 'Porur'], '2026-04-07', 2277, 33)
ON CONFLICT (id) DO NOTHING;

INSERT INTO trigger_events (id, type, zone, city, start_time, end_time, duration_hours, intensity, unit, description, is_active, source) VALUES
  ('trg-001', 'rainfall', 'Velachery', 'Chennai', '2026-03-20T19:00:00+05:30', NULL,                          2,    18, 'mm/hr', 'Heavy rainfall in Velachery — 18mm/hr sustained, exceeding 14mm/hr threshold.', FALSE, 'OpenWeatherMap + IMD'),
  ('trg-002', 'rainfall', 'Adyar',     'Chennai', '2026-03-17T11:30:00+05:30', '2026-03-17T13:00:00+05:30',   1.5,  16, 'mm/hr', 'Heavy rain in Adyar — 16mm/hr for 1.5 hours during lunch rush.',                  FALSE, 'OpenWeatherMap + IMD'),
  ('trg-003', 'rainfall', 'Velachery', 'Chennai', '2026-03-06T08:00:00+05:30', '2026-03-07T20:00:00+05:30',   36,   22, 'mm/hr', 'Cyclone warning — extreme rainfall across Velachery. Full-day disruption.',        FALSE, 'IMD Cyclone Alert'),
  ('trg-004', 'aqi',      'Chennai',   'Chennai', '2026-02-18T13:00:00+05:30', '2026-02-18T18:00:00+05:30',   5,   342, 'AQI',   'AQI spiked to 342 (Hazardous) across Chennai for 5 hours.',                       FALSE, 'CPCB')
ON CONFLICT (id) DO NOTHING;

INSERT INTO payouts (id, worker_id, trigger_event_id, amount, status, breakdown, trigger_type, zone, time_window, payout_rate) VALUES
  ('pay-001', 'w-001', 'trg-001', 420, 'credited', 'Heavy rain Velachery 18mm/hr for 2hrs (7-9PM). Dinner peak: 70% × ₹101/hr × 2hrs = ₹420', 'rainfall', 'Velachery', '7:00 PM – 9:00 PM', '70%'),
  ('pay-002', 'w-001', 'trg-002', 280, 'credited', 'Heavy rain Adyar 16mm/hr for 1.5hrs (11:30AM-1PM). Lunch peak: 60% × ₹101/hr × 1.5hrs = ₹280', 'rainfall', 'Adyar', '11:30 AM – 1:00 PM', '60%'),
  ('pay-003', 'w-001', 'trg-003', 630, 'credited', 'Cyclone warning Velachery 22mm/hr for 36hrs. Multi-window disruption. Total = ₹630', 'rainfall', 'Velachery', 'Full day', '60%'),
  ('pay-004', 'w-001', 'trg-004', 180, 'credited', 'AQI 342 Chennai for 5hrs (1-6PM). Afternoon: 40% × ₹101/hr × 5hrs = ₹180', 'aqi', 'Chennai', '1:00 PM – 6:00 PM', '40%'),
  ('pay-005', 'w-003', 'trg-001', 470, 'credited', 'Heavy rain Velachery 18mm/hr for 2hrs (7-9PM). Dinner peak: 70% × ₹100/hr × 2hrs = ₹470', 'rainfall', 'Velachery', '7:00 PM – 9:00 PM', '70%')
ON CONFLICT (id) DO NOTHING;
