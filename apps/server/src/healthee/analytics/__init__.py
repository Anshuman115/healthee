"""Analytics layer — personal baselines, anomalies, correlations, cutoffs, bio-age.

Every read is v2-native (``derived_daily`` / ``sample`` / ``sleep_session`` /
``manual_entry`` via ``core.db``), so the five legacy view-seam bugs — the
``source='zepp_cloud'`` filter, the v1 metric names, the duplicate
``hrv_sleep_avg_ms`` filter key, and the NULL ``tst_minutes`` that silently
killed the cutoff finder — are impossible by construction (WP6). The statistics
(median±MAD, |z|≥2, Spearman + Mann-Whitney + BH-FDR, Gompertz) are ported
verbatim from the legacy analytics package.
"""
