import 'package:flutter/widgets.dart';

// ignore_for_file: non_constant_identifier_names

/// Manually-maintained localization class for Operion Mobile.
///
/// Supports Romanian (ro) and English (en).
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('ro'),
    Locale('en'),
  ];

  String _get(String key) {
    final strings = _localizedStrings[locale.languageCode] ?? _localizedStrings['en']!;
    return strings[key] ?? key;
  }

  String get appName => _get('appName');
  String get appTagline => _get('appTagline');
  String get auth_login => _get('auth_login');
  String get auth_email => _get('auth_email');
  String get auth_password => _get('auth_password');
  String get auth_loginButton => _get('auth_loginButton');
  String get auth_loggingIn => _get('auth_loggingIn');
  String get auth_loginError => _get('auth_loginError');
  String get auth_biometricTitle => _get('auth_biometricTitle');
  String get auth_biometricHint => _get('auth_biometricHint');
  String get auth_sessionExpired => _get('auth_sessionExpired');
  String get auth_loggedOut => _get('auth_loggedOut');
  String get auth_logout => _get('auth_logout');
  String get auth_logoutConfirm => _get('auth_logoutConfirm');
  String get auth_forgotPassword => _get('auth_forgotPassword');
  String get auth_forgotPasswordSent => _get('auth_forgotPasswordSent');
  String get nav_home => _get('nav_home');
  String get nav_transports => _get('nav_transports');
  String get nav_documents => _get('nav_documents');
  String get nav_messages => _get('nav_messages');
  String get nav_notifications => _get('nav_notifications');
  String get nav_profile => _get('nav_profile');
  String get nav_settings => _get('nav_settings');
  String get nav_jobs => _get('nav_jobs');
  String get nav_fleet => _get('nav_fleet');
  String get nav_drivers => _get('nav_drivers');
  String get nav_alerts => _get('nav_alerts');
  String get nav_analytics => _get('nav_analytics');
  String get nav_map => _get('nav_map');
  String get nav_overview => _get('nav_overview');
  String get nav_copilot => _get('nav_copilot');
  String get nav_fleetTracker => _get('nav_fleetTracker');
  String get nav_more => _get('nav_more');
  String get nav_teams => _get('nav_teams');
  String get nav_profitCalculator => _get('nav_profitCalculator');
  String get nav_routePlanner => _get('nav_routePlanner');
  String get nav_freightExchange => _get('nav_freightExchange');
  String get nav_documentCenter => _get('nav_documentCenter');
  String get nav_localDownload => _get('nav_localDownload');
  String get moreHub_sectionTitle => _get('moreHub_sectionTitle');
  String get moreHub_logout => _get('moreHub_logout');
  String get nav_reportIssue => _get('nav_reportIssue');
  String get reportIssue_title => _get('reportIssue_title');
  String get reportIssue_subject => _get('reportIssue_subject');
  String get reportIssue_subjectHint => _get('reportIssue_subjectHint');
  String get reportIssue_subjectRequired => _get('reportIssue_subjectRequired');
  String get reportIssue_description => _get('reportIssue_description');
  String get reportIssue_descriptionHint => _get('reportIssue_descriptionHint');
  String get reportIssue_descriptionRequired => _get('reportIssue_descriptionRequired');
  String get reportIssue_submit => _get('reportIssue_submit');
  String get reportIssue_success => _get('reportIssue_success');
  String get reportIssue_error => _get('reportIssue_error');

  // ── Route Planner ─────────────────────────────────────────────
  String get routePlanner_origin => _get('routePlanner_origin');
  String get routePlanner_originHint => _get('routePlanner_originHint');
  String get routePlanner_destination => _get('routePlanner_destination');
  String get routePlanner_destinationHint => _get('routePlanner_destinationHint');
  String get routePlanner_stops => _get('routePlanner_stops');
  String get routePlanner_addStop => _get('routePlanner_addStop');
  String get routePlanner_noStops => _get('routePlanner_noStops');
  String get routePlanner_noStopsHint => _get('routePlanner_noStopsHint');
  String get routePlanner_optimize => _get('routePlanner_optimize');
  String get routePlanner_stopNumber => _get('routePlanner_stopNumber');
  String get routePlanner_notice => _get('routePlanner_notice');

  // ── Freight Exchange ──────────────────────────────────────────
  String get freightExchange_searchHint => _get('freightExchange_searchHint');
  String get freightExchange_origin => _get('freightExchange_origin');
  String get freightExchange_destination => _get('freightExchange_destination');
  String get freightExchange_date => _get('freightExchange_date');
  String get freightExchange_cargoType => _get('freightExchange_cargoType');
  String get freightExchange_applyFilters => _get('freightExchange_applyFilters');
  String get freightExchange_clearFilters => _get('freightExchange_clearFilters');
  String get freightExchange_empty => _get('freightExchange_empty');
  String get freightExchange_emptyHint => _get('freightExchange_emptyHint');
  String get freightExchange_loadError => _get('freightExchange_loadError');
  String get freightExchange_loadDetails => _get('freightExchange_loadDetails');
  String get freightExchange_price => _get('freightExchange_price');
  String get freightExchange_weight => _get('freightExchange_weight');
  String get freightExchange_distance => _get('freightExchange_distance');
  String get freightExchange_pickupDate => _get('freightExchange_pickupDate');
  String get freightExchange_deadline => _get('freightExchange_deadline');
  String get freightExchange_acceptAndAssign => _get('freightExchange_acceptAndAssign');
  String get freightExchange_selectTransport => _get('freightExchange_selectTransport');
  String get freightExchange_noTransports => _get('freightExchange_noTransports');
  String get freightExchange_accepting => _get('freightExchange_accepting');
  String get freightExchange_accepted => _get('freightExchange_accepted');
  String get freightExchange_taken => _get('freightExchange_taken');
  String get freightExchange_takenHint => _get('freightExchange_takenHint');
  String get freightExchange_acceptError => _get('freightExchange_acceptError');
  String get freightNegotiation_negotiate => _get('freightNegotiation_negotiate');
  String get freightNegotiation_title => _get('freightNegotiation_title');
  String get freightNegotiation_statusOffered => _get('freightNegotiation_statusOffered');
  String get freightNegotiation_statusCountered => _get('freightNegotiation_statusCountered');
  String get freightNegotiation_statusAccepted => _get('freightNegotiation_statusAccepted');
  String get freightNegotiation_statusRejected => _get('freightNegotiation_statusRejected');
  String get freightNegotiation_statusExpired => _get('freightNegotiation_statusExpired');
  String get freightNegotiation_accept => _get('freightNegotiation_accept');
  String get freightNegotiation_reject => _get('freightNegotiation_reject');
  String get freightNegotiation_counter => _get('freightNegotiation_counter');
  String get freightNegotiation_counterAmount => _get('freightNegotiation_counterAmount');
  String get freightNegotiation_counterSend => _get('freightNegotiation_counterSend');
  String get freightNegotiation_offline => _get('freightNegotiation_offline');
  String get freightNegotiation_error => _get('freightNegotiation_error');
  String get freightNegotiation_you => _get('freightNegotiation_you');
  String get freightNegotiation_empty => _get('freightNegotiation_empty');
  String get freightNegotiation_baseOffer => _get('freightNegotiation_baseOffer');
  String get freightNegotiation_settled => _get('freightNegotiation_settled');
  String get freightNegotiation_justNow => _get('freightNegotiation_justNow');
  String freightNegotiation_minAgo(int minutes) =>
      _get('freightNegotiation_minAgo').replaceAll('{minutes}', '$minutes');
  String freightNegotiation_hoursAgo(int hours) =>
      _get('freightNegotiation_hoursAgo').replaceAll('{hours}', '$hours');
  String freightNegotiation_daysAgo(int days) =>
      _get('freightNegotiation_daysAgo').replaceAll('{days}', '$days');

  String get driver_myDay => _get('driver_myDay');
  String get driver_assignedTransports => _get('driver_assignedTransports');
  String get driver_noTransports => _get('driver_noTransports');
  String get driver_vehicleInfo => _get('driver_vehicleInfo');
  String get driver_expenses => _get('driver_expenses');
  String get driver_documents => _get('driver_documents');
  String get driver_tachograph_title => _get('driver_tachograph_title');
  String get driver_tachograph_note => _get('driver_tachograph_note');
  String driver_copilotContextTrip(String origin, String destination) => _get(
          'driver_copilotContextTrip')
      .replaceAll('{origin}', origin)
      .replaceAll('{destination}', destination);
  String driver_copilotContextTransport(String loadInfo) =>
      _get('driver_copilotContextTransport').replaceAll('{loadInfo}', loadInfo);
  String get transport_status_planned => _get('transport_status_planned');
  String get transport_status_loading => _get('transport_status_loading');
  String get transport_status_in_progress => _get('transport_status_in_progress');
  String get transport_status_in_transit => _get('transport_status_in_transit');
  String get transport_status_delivered => _get('transport_status_delivered');
  String get transport_status_cancelled => _get('transport_status_cancelled');
  String get transport_status_overdue => _get('transport_status_overdue');
  String get transport_status_invoiced => _get('transport_status_invoiced');
  String get transport_status_paid => _get('transport_status_paid');
  String get transport_status_maintenance => _get('transport_status_maintenance');
  String get transport_updateStatus => _get('transport_updateStatus');
  String get transport_navigate => _get('transport_navigate');
  String get transport_route => _get('transport_route');
  String get transport_details => _get('transport_details');
  String get document_upload => _get('document_upload');
  String get document_capture => _get('document_capture');
  String get document_selectGallery => _get('document_selectGallery');
  String get document_cmr => _get('document_cmr');
  String get document_pod => _get('document_pod');
  String get document_invoice => _get('document_invoice');
  String get document_other => _get('document_other');
  String get document_uploading => _get('document_uploading');
  String get document_uploaded => _get('document_uploaded');
  String get document_pending => _get('document_pending');
  String get document_failed => _get('document_failed');
  String get document_noDocuments => _get('document_noDocuments');
  String get expense_new => _get('expense_new');
  String get expense_type => _get('expense_type');
  String get expense_fuel => _get('expense_fuel');
  String get expense_tolls => _get('expense_tolls');
  String get expense_perDiem => _get('expense_perDiem');
  String get expense_other => _get('expense_other');
  String get expense_amount => _get('expense_amount');
  String get expense_date => _get('expense_date');
  String get expense_receipt => _get('expense_receipt');
  String get expense_submit => _get('expense_submit');
  String get vehicle_assigned => _get('vehicle_assigned');
  String get vehicle_plate => _get('vehicle_plate');
  String get vehicle_type => _get('vehicle_type');
  String get vehicle_documents => _get('vehicle_documents');
  String get vehicle_expiry => _get('vehicle_expiry');
  String get message_noMessages => _get('message_noMessages');
  String get message_typeMessage => _get('message_typeMessage');
  String get message_send => _get('message_send');
  String get message_sending => _get('message_sending');
  String get message_sent => _get('message_sent');
  String get message_you => _get('message_you');
  String get notification_newAssignment => _get('notification_newAssignment');
  String get notification_scheduleChange => _get('notification_scheduleChange');
  String get notification_newMessage => _get('notification_newMessage');
  String get notification_alert => _get('notification_alert');
  String get dispatcher_overview => _get('dispatcher_overview');
  String get dispatcher_activeJobs => _get('dispatcher_activeJobs');
  String get dispatcher_activeDrivers => _get('dispatcher_activeDrivers');
  String get dispatcher_openAlerts => _get('dispatcher_openAlerts');
  String get dispatcher_liveFleet => _get('dispatcher_liveFleet');
  String get dispatcher_approve => _get('dispatcher_approve');
  String get dispatcher_reject => _get('dispatcher_reject');
  String get dispatcher_reassign => _get('dispatcher_reassign');
  String get dispatcher_quickActions => _get('dispatcher_quickActions');
  String get dispatcher_jobDetails => _get('dispatcher_jobDetails');
  String get dispatcher_markDelivered => _get('dispatcher_markDelivered');
  String get dispatcher_messageDriver => _get('dispatcher_messageDriver');
  String get dispatcher_reassignConfirm => _get('dispatcher_reassignConfirm');
  String get dispatcher_reassignSuccess => _get('dispatcher_reassignSuccess');
  String get dispatcher_markDeliveredSuccess => _get('dispatcher_markDeliveredSuccess');
  String get dispatcher_contactDriverPhone => _get('dispatcher_contactDriverPhone');
  String get dispatcher_noJobs => _get('dispatcher_noJobs');
  String get dispatcher_all => _get('dispatcher_all');
  String get dispatcher_driver => _get('dispatcher_driver');
  // Phase 5A — quick actions (§9.2)
  String get jobs_pending => _get('jobs_pending');
  String get quickAction_approvePending => _get('quickAction_approvePending');
  String get quickAction_approvePendingSubtitle =>
      _get('quickAction_approvePendingSubtitle');
  String get quickAction_alertCheck => _get('quickAction_alertCheck');
  String get quickAction_alertCheckSubtitle =>
      _get('quickAction_alertCheckSubtitle');
  String get quickAction_scanDocument => _get('quickAction_scanDocument');
  String get quickAction_scanDocumentSubtitle =>
      _get('quickAction_scanDocumentSubtitle');
  // Phase 5A — rich notification inline actions (§9.3)
  String get notification_approve => _get('notification_approve');
  String get notification_snooze => _get('notification_snooze');
  String get notification_view => _get('notification_view');
  String get general_created => _get('general_created');
  String get alert_delay => _get('alert_delay');
  String get alert_maintenance => _get('alert_maintenance');
  String get alert_documentExpiry => _get('alert_documentExpiry');
  String get alert_compliance => _get('alert_compliance');
  String get alert_noAlerts => _get('alert_noAlerts');
  String get analytics_noData => _get('analytics_noData');
  // Phase 2 — analytics date presets
  String get analytics_7d => _get('analytics_7d');
  String get analytics_30d => _get('analytics_30d');
  String get analytics_qtd => _get('analytics_qtd');
  String get analytics_ytd => _get('analytics_ytd');
  String get analytics_custom => _get('analytics_custom');
  String get analytics_customRange => _get('analytics_customRange');
  String get analytics_revenueTab => _get('analytics_revenueTab');
  String get analytics_fleetUtilizationTab => _get('analytics_fleetUtilizationTab');
  String get analytics_driverPerformanceTab => _get('analytics_driverPerformanceTab');
  String get analytics_invoiceAgingTab => _get('analytics_invoiceAgingTab');
  String get analytics_export => _get('analytics_export');
  String get analytics_exportOffline => _get('analytics_exportOffline');
  String get analytics_exportStarted => _get('analytics_exportStarted');
  String get analytics_exportError => _get('analytics_exportError');
  String get analytics_groupByPeriod => _get('analytics_groupByPeriod');
  String get analytics_groupByClient => _get('analytics_groupByClient');
  String get analytics_groupByRoute => _get('analytics_groupByRoute');
  String get analytics_emptyHint => _get('analytics_emptyHint');
  String get analytics_status_active => _get('analytics_status_active');
  String get analytics_status_maintenance => _get('analytics_status_maintenance');
  String get analytics_status_decommissioned => _get('analytics_status_decommissioned');
  String get analytics_driverCol => _get('analytics_driverCol');
  String get analytics_tripsCol => _get('analytics_tripsCol');
  String get analytics_otdCol => _get('analytics_otdCol');
  String get analytics_profitPerKmCol => _get('analytics_profitPerKmCol');
  String get analytics_revenueCol => _get('analytics_revenueCol');
  String get analytics_aging_current => _get('analytics_aging_current');
  String get analytics_aging_31_60 => _get('analytics_aging_31_60');
  String get analytics_aging_61_90 => _get('analytics_aging_61_90');
  String get analytics_aging_overdue => _get('analytics_aging_overdue');
  String get analytics_aging_total => _get('analytics_aging_total');
  // Phase 2 — history
  String get history_tripTitle => _get('history_tripTitle');
  String get history_tripDetails => _get('history_tripDetails');
  String get history_routeDetails => _get('history_routeDetails');
  String get history_netProfit => _get('history_netProfit');
  String get history_routeTitle => _get('history_routeTitle');
  String get history_statusFilter => _get('history_statusFilter');
  String get history_dateFrom => _get('history_dateFrom');
  String get history_dateTo => _get('history_dateTo');
  String get history_clientFilter => _get('history_clientFilter');
  String get history_export => _get('history_export');
  String get history_exportOffline => _get('history_exportOffline');
  String get history_exportStarted => _get('history_exportStarted');
  String get history_exportReady => _get('history_exportReady');
  String get history_exportFailed => _get('history_exportFailed');
  String get history_emptyTrips => _get('history_emptyTrips');
  String get history_emptyRoutes => _get('history_emptyRoutes');
  String get history_distanceKm => _get('history_distanceKm');
  String get history_durationMin => _get('history_durationMin');
  String get history_loadingMore => _get('history_loadingMore');
  String get history_noMore => _get('history_noMore');
  String get history_exportNoJobs => _get('history_exportNoJobs');
  String get history_exportPolling => _get('history_exportPolling');
  // Phase 2 — global search
  String get globalSearch_title => _get('globalSearch_title');
  String get globalSearch_hint => _get('globalSearch_hint');
  String get globalSearch_empty => _get('globalSearch_empty');
  String get globalSearch_minChars => _get('globalSearch_minChars');
  String get globalSearch_trips => _get('globalSearch_trips');
  String get globalSearch_clients => _get('globalSearch_clients');
  String get globalSearch_drivers => _get('globalSearch_drivers');
  String get globalSearch_trucks => _get('globalSearch_trucks');
  String get globalSearch_documents => _get('globalSearch_documents');
  String get globalSearch_more => _get('globalSearch_more');
  String get globalSearch_openSearch => _get('globalSearch_openSearch');
  // Phase 2 — records tiles
  String get records_tripHistory => _get('records_tripHistory');
  String get records_routeHistory => _get('records_routeHistory');
  // Phase 3B — finance (invoicing, e-Factura, CMR, maintenance)
  String get nav_invoicing => _get('nav_invoicing');
  String get nav_maintenance => _get('nav_maintenance');
  String get invoicing_title => _get('invoicing_title');
  String get invoicing_cached => _get('invoicing_cached');
  String get invoicing_searchHint => _get('invoicing_searchHint');
  String get invoicing_emptyTitle => _get('invoicing_emptyTitle');
  String get invoicing_emptyHint => _get('invoicing_emptyHint');
  String get invoicing_total => _get('invoicing_total');
  String get invoicing_due => _get('invoicing_due');
  String get invoicing_statusAll => _get('invoicing_statusAll');
  String get invoicing_statusDraft => _get('invoicing_statusDraft');
  String get invoicing_statusFinalized => _get('invoicing_statusFinalized');
  String get invoicing_statusXml => _get('invoicing_statusXml');
  String get invoicing_statusPaid => _get('invoicing_statusPaid');
  String get invoicing_statusCancelled => _get('invoicing_statusCancelled');
  String get invoicing_stepperTitle => _get('invoicing_stepperTitle');
  String get invoicing_stepDraft => _get('invoicing_stepDraft');
  String get invoicing_stepFinalized => _get('invoicing_stepFinalized');
  String get invoicing_stepXml => _get('invoicing_stepXml');
  String get invoicing_stepPaid => _get('invoicing_stepPaid');
  String get invoicing_stepCancelled => _get('invoicing_stepCancelled');
  String get invoicing_client => _get('invoicing_client');
  String get invoicing_clientHint => _get('invoicing_clientHint');
  String get invoicing_clientSearch => _get('invoicing_clientSearch');
  String get invoicing_clientRequired => _get('invoicing_clientRequired');
  String get invoicing_trip => _get('invoicing_trip');
  String get invoicing_tripShort => _get('invoicing_tripShort');
  String get invoicing_tripHint => _get('invoicing_tripHint');
  String get invoicing_tripSearch => _get('invoicing_tripSearch');
  String get invoicing_noTrips => _get('invoicing_noTrips');
  String get invoicing_noClients => _get('invoicing_noClients');
  String get invoicing_lineItems => _get('invoicing_lineItems');
  String get invoicing_addLine => _get('invoicing_addLine');
  String get invoicing_noLines => _get('invoicing_noLines');
  String get invoicing_noLinesHint => _get('invoicing_noLinesHint');
  String get invoicing_unnamedLine => _get('invoicing_unnamedLine');
  String get invoicing_vatShort => _get('invoicing_vatShort');
  String get invoicing_subtotal => _get('invoicing_subtotal');
  String get invoicing_vat => _get('invoicing_vat');
  String get invoicing_lineItem => _get('invoicing_lineItem');
  String get invoicing_description => _get('invoicing_description');
  String get invoicing_descriptionRequired => _get('invoicing_descriptionRequired');
  String get invoicing_quantity => _get('invoicing_quantity');
  String get invoicing_quantityRequired => _get('invoicing_quantityRequired');
  String get invoicing_unitPrice => _get('invoicing_unitPrice');
  String get invoicing_priceRequired => _get('invoicing_priceRequired');
  String get invoicing_discountPct => _get('invoicing_discountPct');
  String get invoicing_discountAmount => _get('invoicing_discountAmount');
  String get invoicing_vatRate => _get('invoicing_vatRate');
  String get invoicing_invoiceNumber => _get('invoicing_invoiceNumber');
  String get invoicing_saveDraft => _get('invoicing_saveDraft');
  String get invoicing_finalize => _get('invoicing_finalize');
  String get invoicing_generateXml => _get('invoicing_generateXml');
  String get invoicing_markPaid => _get('invoicing_markPaid');
  String get invoicing_noAction => _get('invoicing_noAction');
  String get invoicing_cancel => _get('invoicing_cancel');
  String get invoicing_viewPdf => _get('invoicing_viewPdf');
  String get invoicing_pdfTitle => _get('invoicing_pdfTitle');
  String get invoicing_pdfError => _get('invoicing_pdfError');
  String get invoicing_savedDraft => _get('invoicing_savedDraft');
  String get invoicing_savedOffline => _get('invoicing_savedOffline');
  String get invoicing_queuedOffline => _get('invoicing_queuedOffline');
  String get invoicing_requiresConnection => _get('invoicing_requiresConnection');
  String get invoicing_biometricReason => _get('invoicing_biometricReason');
  String get invoicing_biometricDenied => _get('invoicing_biometricDenied');
  String get invoicing_finalizedOk => _get('invoicing_finalizedOk');
  String get invoicing_xmlGeneratedOk => _get('invoicing_xmlGeneratedOk');
  String get invoicing_paidOk => _get('invoicing_paidOk');
  String get invoicing_cancelledOk => _get('invoicing_cancelledOk');
  String get invoicing_cmrTitle => _get('invoicing_cmrTitle');
  String get invoicing_cmrSender => _get('invoicing_cmrSender');
  String get invoicing_cmrSenderName => _get('invoicing_cmrSenderName');
  String get invoicing_cmrSenderNameRequired => _get('invoicing_cmrSenderNameRequired');
  String get invoicing_cmrSenderAddress => _get('invoicing_cmrSenderAddress');
  String get invoicing_cmrSenderAddressRequired => _get('invoicing_cmrSenderAddressRequired');
  String get invoicing_cmrConsignee => _get('invoicing_cmrConsignee');
  String get invoicing_cmrFromTrip => _get('invoicing_cmrFromTrip');
  String get invoicing_cmrCarrier => _get('invoicing_cmrCarrier');
  String get invoicing_cmrCarrierName => _get('invoicing_cmrCarrierName');
  String get invoicing_cmrCarrierLicense => _get('invoicing_cmrCarrierLicense');
  String get invoicing_cmrGoods => _get('invoicing_cmrGoods');
  String get invoicing_cmrInstructions => _get('invoicing_cmrInstructions');
  String get invoicing_cmrLanguage => _get('invoicing_cmrLanguage');
  String get invoicing_cmrCopies => _get('invoicing_cmrCopies');
  String get invoicing_cmrIncludeStamps => _get('invoicing_cmrIncludeStamps');
  String get invoicing_cmrRemarks => _get('invoicing_cmrRemarks');
  String get invoicing_cmrSignatures => _get('invoicing_cmrSignatures');
  String get invoicing_cmrClearSignature => _get('invoicing_cmrClearSignature');
  String get invoicing_cmrSave => _get('invoicing_cmrSave');
  String get invoicing_cmrSaved => _get('invoicing_cmrSaved');
  String get maintenance_costTrend => _get('maintenance_costTrend');
  String get maintenance_schedules => _get('maintenance_schedules');
  String get maintenance_overdueOnly => _get('maintenance_overdueOnly');
  String get maintenance_emptyTitle => _get('maintenance_emptyTitle');
  String get maintenance_emptyHint => _get('maintenance_emptyHint');
  String get maintenance_byType => _get('maintenance_byType');
  String get maintenance_overdue => _get('maintenance_overdue');
  String get maintenance_every => _get('maintenance_every');
  String get maintenance_months => _get('maintenance_months');
  String get maintenance_nextDue => _get('maintenance_nextDue');
  String get maintenance_lastKm => _get('maintenance_lastKm');
  String get maintenance_addSchedule => _get('maintenance_addSchedule');
  String get maintenance_truck => _get('maintenance_truck');
  String get maintenance_truckRequired => _get('maintenance_truckRequired');
  String get maintenance_type => _get('maintenance_type');
  String get maintenance_typeRequired => _get('maintenance_typeRequired');
  String get maintenance_intervalKm => _get('maintenance_intervalKm');
  String get maintenance_intervalMonths => _get('maintenance_intervalMonths');
  String get maintenance_fixedExpiry => _get('maintenance_fixedExpiry');
  String get maintenance_fixedExpiryHint => _get('maintenance_fixedExpiryHint');
  String get maintenance_scheduleAdded => _get('maintenance_scheduleAdded');
  String get ocr_results => _get('ocr_results');
  String get ocr_processing => _get('ocr_processing');
  String get ocr_confidence => _get('ocr_confidence');
  String get general_cancel => _get('general_cancel');
  String get general_confirm => _get('general_confirm');
  String get general_save => _get('general_save');
  String get general_delete => _get('general_delete');
  String get general_edit => _get('general_edit');
  String get general_retry => _get('general_retry');
  String get general_loading => _get('general_loading');
  String get general_error => _get('general_error');
  String get general_noInternet => _get('general_noInternet');
  String get general_offline => _get('general_offline');
  String get general_lastUpdated => _get('general_lastUpdated');
  String get general_minAgo => _get('general_minAgo');
  String get general_justNow => _get('general_justNow');
  String get general_hourAgo => _get('general_hourAgo');
  String get general_hoursAgo => _get('general_hoursAgo');
  String get general_pendingSync => _get('general_pendingSync');
  String get general_comingSoon => _get('general_comingSoon');
  String get general_comingSoonDescription => _get('general_comingSoonDescription');
  String get general_openDesktop => _get('general_openDesktop');
  String get general_yes => _get('general_yes');
  String get general_no => _get('general_no');
  String get settings_language => _get('settings_language');
  String get settings_appearance => _get('settings_appearance');
  String get settings_languageRo => _get('settings_languageRo');
  String get settings_languageEn => _get('settings_languageEn');
  String get settings_theme => _get('settings_theme');
  String get settings_themeSystem => _get('settings_themeSystem');
  String get settings_themeLight => _get('settings_themeLight');
  String get settings_themeDark => _get('settings_themeDark');
  String get settings_appVersion => _get('settings_appVersion');

  // ── Phase 4B — navigation tiles ────────────────────────────────
  String get nav_teamsManagement => _get('nav_teamsManagement');
  String get nav_tachograph => _get('nav_tachograph');

  // ── Phase 4B — Settings expansion (§4.10) ─────────────────────
  String get settings_saved => _get('settings_saved');
  String get settings_saveFailed => _get('settings_saveFailed');
  String get settings_saving => _get('settings_saving');
  String get settings_save => _get('settings_save');
  String get settings_companyProfile => _get('settings_companyProfile');
  String get settings_legalName => _get('settings_legalName');
  String get settings_vatNumber => _get('settings_vatNumber');
  String get settings_address => _get('settings_address');
  String get settings_invoiceFooter => _get('settings_invoiceFooter');
  String get settings_smtp => _get('settings_smtp');
  String get settings_smtpServer => _get('settings_smtpServer');
  String get settings_smtpPort => _get('settings_smtpPort');
  String get settings_smtpUser => _get('settings_smtpUser');
  String get settings_smtpPassword => _get('settings_smtpPassword');
  String get settings_configuredPlaceholder => _get('settings_configuredPlaceholder');
  String get settings_sendTestEmail => _get('settings_sendTestEmail');
  String get settings_testEmailSent => _get('settings_testEmailSent');
  String get settings_testEmailFailed => _get('settings_testEmailFailed');
  String get settings_tracking => _get('settings_tracking');
  String get settings_trackingApiKey => _get('settings_trackingApiKey');
  String get settings_trackingNone => _get('settings_trackingNone');
  String get settings_maintenanceThresholds => _get('settings_maintenanceThresholds');
  String get settings_maintenanceAlertDays => _get('settings_maintenanceAlertDays');
  String get settings_tachoWarningDays => _get('settings_tachoWarningDays');
  String get settings_tachoCriticalDays => _get('settings_tachoCriticalDays');
  String get settings_notifications => _get('settings_notifications');
  String get settings_notifCritical => _get('settings_notifCritical');
  String get settings_notifWarning => _get('settings_notifWarning');
  String get settings_notifInfo => _get('settings_notifInfo');
  String get settings_quietHours => _get('settings_quietHours');
  String get settings_dataUsage => _get('settings_dataUsage');
  String get settings_wifiOnlyLargeSyncs => _get('settings_wifiOnlyLargeSyncs');
  String get settings_wifiOnlyLargeSyncsHint => _get('settings_wifiOnlyLargeSyncsHint');
  String get settings_biometricLock => _get('settings_biometricLock');
  String get settings_biometricUnlock => _get('settings_biometricUnlock');
  String get settings_biometricUnlockHint => _get('settings_biometricUnlockHint');
  String get settings_requireFinancial => _get('settings_requireFinancial');
  String get settings_requireFinancialHint => _get('settings_requireFinancialHint');

  // ── Phase 4B — Wi-Fi-only gate (§4.10) ─────────────────────────
  String get wifi_only_message => _get('wifi_only_message');

  // ── Phase 4B — Team Management (§4.9) ──────────────────────────
  String get team_inviteTitle => _get('team_inviteTitle');
  String get team_inviteEmail => _get('team_inviteEmail');
  String get team_inviteEmailRequired => _get('team_inviteEmailRequired');
  String get team_inviteEmailInvalid => _get('team_inviteEmailInvalid');
  String get team_inviteRole => _get('team_inviteRole');
  String get team_inviteBtn => _get('team_inviteBtn');
  String get team_memberDetails => _get('team_memberDetails');
  String get team_inviting => _get('team_inviting');
  String get team_inviteSent => _get('team_inviteSent');
  String get team_inviteFailed => _get('team_inviteFailed');
  String get team_requiresConnection => _get('team_requiresConnection');
  String get team_notPermitted => _get('team_notPermitted');
  String get team_deactivateTitle => _get('team_deactivateTitle');
  String team_deactivateMessage(String name) =>
      _get('team_deactivateMessage').replaceAll('{name}', name);
  String get team_deactivate => _get('team_deactivate');
  String get team_deactivated => _get('team_deactivated');
  String get team_actionFailed => _get('team_actionFailed');
  String get team_roleUpdated => _get('team_roleUpdated');
  String get team_emptyTitle => _get('team_emptyTitle');
  String get team_emptyHint => _get('team_emptyHint');
  String get team_cached => _get('team_cached');
  String get team_active => _get('team_active');
  String get team_inactive => _get('team_inactive');
  String get team_moreActions => _get('team_moreActions');

  // ── Phase 4B — Tachograph (§4.7) ───────────────────────────────
  String get tacho_selectDriverTitle => _get('tacho_selectDriverTitle');
  String get tacho_selectDriver => _get('tacho_selectDriver');
  String get tacho_driverSearch => _get('tacho_driverSearch');
  String get tacho_noDrivers => _get('tacho_noDrivers');
  String get tacho_noDriverSelected => _get('tacho_noDriverSelected');
  String get tacho_importFile => _get('tacho_importFile');
  String get tacho_importing => _get('tacho_importing');
  String get tacho_processing => _get('tacho_processing');
  String get tacho_uploadFailed => _get('tacho_uploadFailed');
  String get tacho_requiresConnection => _get('tacho_requiresConnection');
  String get tacho_wifiOnly => _get('tacho_wifiOnly');
  String get tacho_imported => _get('tacho_imported');
  String get tacho_empty => _get('tacho_empty');
  String get tacho_emptyHint => _get('tacho_emptyHint');
  String get tacho_complianceTitle => _get('tacho_complianceTitle');
  String get tacho_weeklyDriving => _get('tacho_weeklyDriving');
  String get tacho_overLimit => _get('tacho_overLimit');
  String get tacho_days => _get('tacho_days');
  String get tacho_violations => _get('tacho_violations');
  String get tacho_noViolations => _get('tacho_noViolations');

  // ── AI Co-Pilot ─────────────────────────────────────────────────
  String get ai_title => _get('ai_title');
  String get ai_emptyStateMessage => _get('ai_emptyStateMessage');
  String get ai_emptyStatePrompt => _get('ai_emptyStatePrompt');
  String get ai_clarifyPlaceholder => _get('ai_clarifyPlaceholder');
  String get ai_newConversation => _get('ai_newConversation');
  String get ai_placeholder => _get('ai_placeholder');
  String get ai_confirmTitle => _get('ai_confirmTitle');
  String get ai_confirmMessage => _get('ai_confirmMessage');
  String get copilot_level3_title => _get('copilot_level3_title');
  String get copilot_level3_warning => _get('copilot_level3_warning');
  String get copilot_level3_hint => _get('copilot_level3_hint');
  String copilot_level3_phrase(String phrase) =>
      _get('copilot_level3_phrase').replaceAll('{phrase}', phrase);
  String get copilot_maintenanceCapture => _get('copilot_maintenanceCapture');
  String get copilot_maintenanceEmpty => _get('copilot_maintenanceEmpty');
  String get copilot_maintenanceSelectTruck =>
      _get('copilot_maintenanceSelectTruck');
  String get copilot_maintenanceConfirm =>
      _get('copilot_maintenanceConfirm');
  String get copilot_maintenanceSaved => _get('copilot_maintenanceSaved');

  // ── Profile screen ──────────────────────────────────────────────
  String get profile_personalInfo => _get('profile_personalInfo');
  String get profile_driverInfo => _get('profile_driverInfo');
  String get profile_quickLinks => _get('profile_quickLinks');
  String get profile_licenseNumber => _get('profile_licenseNumber');
  String get profile_licenseCategory => _get('profile_licenseCategory');
  String get profile_licenseExpiry => _get('profile_licenseExpiry');
  String get profile_phone => _get('profile_phone');
  String get profile_displayName => _get('profile_displayName');
  String get profile_noDriverInfo => _get('profile_noDriverInfo');
  String get profile_documentLicense => _get('profile_documentLicense');
  String get profile_documentPassport => _get('profile_documentPassport');
  String get profile_documentAdr => _get('profile_documentAdr');
  String get profile_selectCamera => _get('profile_selectCamera');
  String get profile_selectGallery => _get('profile_selectGallery');
  String get profile_noDocuments => _get('profile_noDocuments');
  String get profile_uploadSuccess => _get('profile_uploadSuccess');
  String get profile_uploadError => _get('profile_uploadError');

  // ── Driver Overview ──────────────────────────────────────────
  String get driverOverview_emptyState => _get('driverOverview_emptyState');
  String get driverOverview_emptyStateSubtitle => _get('driverOverview_emptyStateSubtitle');
  String get driverOverview_etaUnavailable => _get('driverOverview_etaUnavailable');

  // ── Transport ────────────────────────────────────────────────
  String get transport_statusUpdated => _get('transport_statusUpdated');
  String get transport_eta => _get('transport_eta');
  String get transport_elapsedTime => _get('transport_elapsedTime');

  // ── Route Share ──────────────────────────────────────────────
  String get routeShare_noData => _get('routeShare_noData');
  String get routeShare_noDataSubtitle => _get('routeShare_noDataSubtitle');
  String get routeShare_distance => _get('routeShare_distance');
  String get routeShare_estimatedTime => _get('routeShare_estimatedTime');
  String get routeShare_offRoute => _get('routeShare_offRoute');
  String get routeShare_backgroundBanner => _get('routeShare_backgroundBanner');
  String get routeShare_permissionDenied => _get('routeShare_permissionDenied');
  /// Persistent foreground-service notification title template (the
  /// `{instruction}` placeholder is filled by the navigation layer §7.2.3).
  String get routeShare_fgNotificationTitle =>
      _get('routeShare_fgNotificationTitle');
  /// Persistent foreground-service notification body template (`{distance}`
  /// and `{eta}` placeholders, §7.2.3).
  String get routeShare_fgNotificationBody =>
      _get('routeShare_fgNotificationBody');
  /// Android notification-channel name for the navigation foreground service.
  String get routeShare_fgChannelName => _get('routeShare_fgChannelName');

  // ── Transport Actions ────────────────────────────────────────
  String get transport_action_startLoading => _get('transport_action_startLoading');
  String get transport_action_depart => _get('transport_action_depart');
  String get transport_action_markDelivered => _get('transport_action_markDelivered');
  String get transport_action_reportDelay => _get('transport_action_reportDelay');
  String get transport_action_noActions => _get('transport_action_noActions');

  // ── Document Center ──────────────────────────────────────────
  String get documentCenter_title => _get('documentCenter_title');
  String get documentCenter_documents => _get('documentCenter_documents');
  String get documentCenter_automation => _get('documentCenter_automation');
  String get documentCenter_ocrTitle => _get('documentCenter_ocrTitle');
  String get documentCenter_ocrDescription => _get('documentCenter_ocrDescription');
  String get documentCenter_capturePhoto => _get('documentCenter_capturePhoto');
  String get documentCenter_uploadConfirmed => _get('documentCenter_uploadConfirmed');
  String get documentCenter_uploadInProgress => _get('documentCenter_uploadInProgress');
  String get documentCenter_uploadError => _get('documentCenter_uploadError');
  String get documentCenter_processingHint => _get('documentCenter_processingHint');
  String get documentCenter_captureAnother => _get('documentCenter_captureAnother');
  String get documentCenter_documentsEmpty => _get('documentCenter_documentsEmpty');
  String get documentCenter_documentsError => _get('documentCenter_documentsError');

  // ── Local Download ───────────────────────────────────────────
  String get localDownload_title => _get('localDownload_title');
  String get localDownload_selectCategory => _get('localDownload_selectCategory');
  String get localDownload_download => _get('localDownload_download');
  String get localDownload_categoryDocuments => _get('localDownload_categoryDocuments');
  String get localDownload_categoryInvoices => _get('localDownload_categoryInvoices');
  String get localDownload_categoryReceipts => _get('localDownload_categoryReceipts');
  String get localDownload_categoryOcrResults => _get('localDownload_categoryOcrResults');
  String get localDownload_categoryTripHistory => _get('localDownload_categoryTripHistory');
  String get localDownload_dateFrom => _get('localDownload_dateFrom');
  String get localDownload_dateTo => _get('localDownload_dateTo');
  String get localDownload_progress => _get('localDownload_progress');
  String get localDownload_complete => _get('localDownload_complete');
  String get localDownload_downloadAll => _get('localDownload_downloadAll');
  String get localDownload_manifestEmpty => _get('localDownload_manifestEmpty');
  String get localDownload_manifestError => _get('localDownload_manifestError');
  String get localDownload_saved => _get('localDownload_saved');

  // ── Phase 1B: Records / Fleet / Drivers / Clients (§4.1–4.3) ──
  String get nav_records => _get('nav_records');
  String get records_searchHint => _get('records_searchHint');
  String get records_emptyTitle => _get('records_emptyTitle');
  String get records_emptyHint => _get('records_emptyHint');
  String get records_fleet => _get('records_fleet');
  String get records_drivers => _get('records_drivers');
  String get records_clients => _get('records_clients');
  String get fleet_cached => _get('fleet_cached');
  String get fleet_searchHint => _get('fleet_searchHint');
  String get fleet_emptyTitle => _get('fleet_emptyTitle');
  String get fleet_emptyHint => _get('fleet_emptyHint');
  String get fleet_statusActive => _get('fleet_statusActive');
  String get fleet_statusMaintenance => _get('fleet_statusMaintenance');
  String get fleet_statusDecommissioned => _get('fleet_statusDecommissioned');
  String get fleet_edit => _get('fleet_edit');
  String get fleet_decommission => _get('fleet_decommission');
  String get fleet_decommissionConfirm => _get('fleet_decommissionConfirm');
  String get fleet_overview => _get('fleet_overview');
  String get fleet_maintenance => _get('fleet_maintenance');
  String get fleet_documents => _get('fleet_documents');
  String get fleet_assignments => _get('fleet_assignments');
  String get fleet_vin => _get('fleet_vin');
  String get fleet_year => _get('fleet_year');
  String get fleet_health => _get('fleet_health');
  String get fleet_currentDriver => _get('fleet_currentDriver');
  String get fleet_noMaintenance => _get('fleet_noMaintenance');
  String get fleet_recordWorkHint => _get('fleet_recordWorkHint');
  String get fleet_documentsPlaceholder => _get('fleet_documentsPlaceholder');
  String get fleet_noDocuments => _get('fleet_noDocuments');
  String get fleet_assignmentsNote => _get('fleet_assignmentsNote');
  String get fleet_editTitle => _get('fleet_editTitle');
  String get fleet_plate => _get('fleet_plate');
  String get fleet_plateRequired => _get('fleet_plateRequired');
  String get fleet_brand => _get('fleet_brand');
  String get fleet_brandRequired => _get('fleet_brandRequired');
  String get fleet_model => _get('fleet_model');
  String get fleet_modelRequired => _get('fleet_modelRequired');
  String get fleet_recordWork => _get('fleet_recordWork');
  String get fleet_date => _get('fleet_date');
  String get fleet_category => _get('fleet_category');
  String get fleet_cost => _get('fleet_cost');
  String get fleet_costRequired => _get('fleet_costRequired');
  String get fleet_vendor => _get('fleet_vendor');
  String get fleet_notes => _get('fleet_notes');
  String get fleet_categoryOil => _get('fleet_categoryOil');
  String get fleet_categoryTires => _get('fleet_categoryTires');
  String get fleet_categoryBrakes => _get('fleet_categoryBrakes');
  String get fleet_categoryEngine => _get('fleet_categoryEngine');
  String get fleet_categoryBodywork => _get('fleet_categoryBodywork');
  String get fleet_categoryInspection => _get('fleet_categoryInspection');
  String get fleet_categoryOther => _get('fleet_categoryOther');
  String get teams_filterExpiring => _get('teams_filterExpiring');
  String get teams_expired => _get('teams_expired');
  String get teams_daysShort => _get('teams_daysShort');
  String get teams_editDriver => _get('teams_editDriver');
  String get teams_overview => _get('teams_overview');
  String get teams_compliance => _get('teams_compliance');
  String get teams_tacho => _get('teams_tacho');
  String get teams_assignments => _get('teams_assignments');
  String get teams_renew => _get('teams_renew');
  String get teams_adrExpiry => _get('teams_adrExpiry');
  String get teams_expiryWindow => _get('teams_expiryWindow');
  String get teams_weeklyDriving => _get('teams_weeklyDriving');
  String get teams_weeklyLimit => _get('teams_weeklyLimit');
  String get teams_weeklyOverLimit => _get('teams_weeklyOverLimit');
  String get teams_tachoEmpty => _get('teams_tachoEmpty');
  String get teams_assignmentsNote => _get('teams_assignmentsNote');
  String get teams_editTitle => _get('teams_editTitle');
  String get teams_phone => _get('teams_phone');
  String get teams_email => _get('teams_email');
  String get tacho_driving => _get('tacho_driving');
  String get tacho_working => _get('tacho_working');
  String get tacho_rest => _get('tacho_rest');
  String get tacho_availability => _get('tacho_availability');
  String get nav_clients => _get('nav_clients');
  String get clients_cached => _get('clients_cached');
  String get clients_searchHint => _get('clients_searchHint');
  String get clients_emptyTitle => _get('clients_emptyTitle');
  String get clients_emptyHint => _get('clients_emptyHint');
  String get clients_paymentTerms => _get('clients_paymentTerms');
  String get clients_daysShort => _get('clients_daysShort');
  String get clients_active => _get('clients_active');
  String get clients_inactive => _get('clients_inactive');
  String get clients_editTitle => _get('clients_editTitle');
  String get clients_name => _get('clients_name');
  String get clients_nameRequired => _get('clients_nameRequired');
  String get clients_vatNumber => _get('clients_vatNumber');
  String get clients_address => _get('clients_address');
  String get clients_details => _get('clients_details');
  String get clients_contacts => _get('clients_contacts');
  String get clients_invoices => _get('clients_invoices');
  String get clients_trips => _get('clients_trips');
  String get clients_rating => _get('clients_rating');
  String get clients_noPermission => _get('clients_noPermission');
  String get clients_addContact => _get('clients_addContact');
  String get clients_noContacts => _get('clients_noContacts');
  String get clients_addContactHint => _get('clients_addContactHint');
  String get clients_recentInvoices => _get('clients_recentInvoices');
  String get clients_recentTrips => _get('clients_recentTrips');
  String get clients_invoicesPlaceholder => _get('clients_invoicesPlaceholder');
  String get clients_invoicesPlaceholderHint => _get('clients_invoicesPlaceholderHint');
  String get clients_tripsPlaceholder => _get('clients_tripsPlaceholder');
  String get clients_tripsPlaceholderHint => _get('clients_tripsPlaceholderHint');
  String get clients_noInvoices => _get('clients_noInvoices');
  String get clients_noInvoicesHint => _get('clients_noInvoicesHint');
  String get clients_noTrips => _get('clients_noTrips');
  String get clients_noTripsHint => _get('clients_noTripsHint');
  String get clients_editContactTitle => _get('clients_editContactTitle');
  String get clients_contactName => _get('clients_contactName');
  String get clients_contactNameRequired => _get('clients_contactNameRequired');
  String get clients_contactRole => _get('clients_contactRole');
  String get clients_contactPhone => _get('clients_contactPhone');
  String get clients_contactEmail => _get('clients_contactEmail');
  String get clients_merge => _get('clients_merge');
  String get clients_mergeTarget => _get('clients_mergeTarget');
  String get clients_mergeSources => _get('clients_mergeSources');
  String get clients_mergeTypeConfirm => _get('clients_mergeTypeConfirm');
  String get clients_mergeOffline => _get('clients_mergeOffline');
  String get clients_mergeBtn => _get('clients_mergeBtn');
  String get clients_mergeSummary => _get('clients_mergeSummary');
  String get clients_tripsShort => _get('clients_tripsShort');
  String get clients_invoicesShort => _get('clients_invoicesShort');
  String get clients_contactsShort => _get('clients_contactsShort');

  // ── Profit Calculator ────────────────────────────────────────
  String get profitCalculator_title => _get('profitCalculator_title');
  String get profitCalculator_price => _get('profitCalculator_price');
  String get profitCalculator_fuelCost => _get('profitCalculator_fuelCost');
  String get profitCalculator_tollCost => _get('profitCalculator_tollCost');
  String get profitCalculator_driverCost => _get('profitCalculator_driverCost');
  String get profitCalculator_extraCosts => _get('profitCalculator_extraCosts');
  String get profitCalculator_calculate => _get('profitCalculator_calculate');
  String get profitCalculator_totalCosts => _get('profitCalculator_totalCosts');
  String get profitCalculator_profit => _get('profitCalculator_profit');
  String get profitCalculator_profitMargin => _get('profitCalculator_profitMargin');
  String get profitCalculator_currencySymbol => _get('profitCalculator_currencySymbol');

  // ── Teams ────────────────────────────────────────────────────
  String get teams_filterAll => _get('teams_filterAll');
  String get teams_filterAvailable => _get('teams_filterAvailable');
  String get teams_filterDriving => _get('teams_filterDriving');
  String get teams_filterOff => _get('teams_filterOff');
  String get teams_placeholder => _get('teams_placeholder');
  String get teams_licenseNumber => _get('teams_licenseNumber');
  String get teams_licenseCategory => _get('teams_licenseCategory');
  String get teams_licenseExpiry => _get('teams_licenseExpiry');
  String get teams_medicalExpiry => _get('teams_medicalExpiry');
  String get teams_assignedVehicle => _get('teams_assignedVehicle');
  String get teams_assignedTransport => _get('teams_assignedTransport');
  String get teams_licenseValid => _get('teams_licenseValid');
  String get teams_licenseExpiringSoon => _get('teams_licenseExpiringSoon');
  String get teams_licenseExpired => _get('teams_licenseExpired');
  String get teams_notAssigned => _get('teams_notAssigned');
  String get teams_detailLoadError => _get('teams_detailLoadError');

  // ── §2 Feature-parity (row 1: overview) ─────────────────────────
  String get dispatcher_revenueTrend => _get('dispatcher_revenueTrend');
  String get dispatcher_activityFeed => _get('dispatcher_activityFeed');
  String get dispatcher_activityEmpty => _get('dispatcher_activityEmpty');

  // ── §2 Feature-parity (row 3: route planner) ────────────────────
  String get routePlanner_profile => _get('routePlanner_profile');
  String get routePlanner_profileTruck => _get('routePlanner_profileTruck');
  String get routePlanner_profileCar => _get('routePlanner_profileCar');
  String get routePlanner_profilePedestrian => _get('routePlanner_profilePedestrian');
  String get routePlanner_avoidCountries => _get('routePlanner_avoidCountries');
  String get routePlanner_avoidCountriesHint => _get('routePlanner_avoidCountriesHint');
  String get routePlanner_selectCountries => _get('routePlanner_selectCountries');

  // ── §2 Feature-parity (row 11: document center) ─────────────────
  String get documentCenter_searchHint => _get('documentCenter_searchHint');
  String get documentCenter_allCategories => _get('documentCenter_allCategories');
  String get documentCenter_versions => _get('documentCenter_versions');
  String get documentCenter_noVersions => _get('documentCenter_noVersions');
  String get documentCenter_versionNumber => _get('documentCenter_versionNumber');
  String get documentCenter_uploadedBy => _get('documentCenter_uploadedBy');
  String get documentCenter_previewUnavailable => _get('documentCenter_previewUnavailable');

  // ── §2 Feature-parity (row 5: dispatch board) ───────────────────
  String get jobs_viewList => _get('jobs_viewList');
  String get jobs_viewKanban => _get('jobs_viewKanban');
  String get jobs_viewTimeline => _get('jobs_viewTimeline');
  String get jobs_kanbanHint => _get('jobs_kanbanHint');
  String get jobs_kanbanEmpty => _get('jobs_kanbanEmpty');
  String get jobs_moved => _get('jobs_moved');
  String get jobs_undo => _get('jobs_undo');
  String get jobs_moveFailed => _get('jobs_moveFailed');
  String get jobs_timelineNoDates => _get('jobs_timelineNoDates');
  String get jobs_timelineUnassigned => _get('jobs_timelineUnassigned');

  // ── §2 Feature-parity (row 7: freight exchange) ─────────────────
  String get freightExchange_moreFilters => _get('freightExchange_moreFilters');
  String get freightExchange_advancedSearch => _get('freightExchange_advancedSearch');
  String get freightExchange_pickupFrom => _get('freightExchange_pickupFrom');
  String get freightExchange_pickupTo => _get('freightExchange_pickupTo');
  String get freightExchange_weightMin => _get('freightExchange_weightMin');
  String get freightExchange_weightMax => _get('freightExchange_weightMax');
  String get freightExchange_trailerType => _get('freightExchange_trailerType');
  String get freightExchange_priceMin => _get('freightExchange_priceMin');
  String get freightExchange_priceMax => _get('freightExchange_priceMax');
  String get freightExchange_savedSearches => _get('freightExchange_savedSearches');
  String get freightExchange_saveCurrentSearch => _get('freightExchange_saveCurrentSearch');
  String get freightExchange_savedSearchLabel => _get('freightExchange_savedSearchLabel');
  String get freightExchange_savedSearchLabelHint => _get('freightExchange_savedSearchLabelHint');
  String get freightExchange_searchSaved => _get('freightExchange_searchSaved');
  String get freightExchange_saveSearchError => _get('freightExchange_saveSearchError');
  String get freightExchange_noSavedSearches => _get('freightExchange_noSavedSearches');
  String get freightExchange_deleteSearch => _get('freightExchange_deleteSearch');
  String get freightExchange_deleteSearchConfirm => _get('freightExchange_deleteSearchConfirm');
  String get freightExchange_runSearch => _get('freightExchange_runSearch');
  String get freightExchange_evaluate => _get('freightExchange_evaluate');
  String get freightExchange_evaluation => _get('freightExchange_evaluation');
  String get freightExchange_evaluationError => _get('freightExchange_evaluationError');
  String get freightExchange_estimatedRevenue => _get('freightExchange_estimatedRevenue');
  String get freightExchange_expectedProfit => _get('freightExchange_expectedProfit');
  String get freightExchange_profitMargin => _get('freightExchange_profitMargin');
  String get freightExchange_fuelCost => _get('freightExchange_fuelCost');
  String get freightExchange_tollCost => _get('freightExchange_tollCost');
  String get freightExchange_driverSalary => _get('freightExchange_driverSalary');
  String get freightExchange_deadheadKm => _get('freightExchange_deadheadKm');
  String get freightExchange_durationHours => _get('freightExchange_durationHours');
  String get freightExchange_riskScore => _get('freightExchange_riskScore');
  String get freightExchange_vehicleCompatibility => _get('freightExchange_vehicleCompatibility');
  String get freightExchange_vehicleCompatible => _get('freightExchange_vehicleCompatible');
  String get freightExchange_vehicleIncompatible => _get('freightExchange_vehicleIncompatible');
  String get freightExchange_riskLow => _get('freightExchange_riskLow');
  String get freightExchange_riskMedium => _get('freightExchange_riskMedium');
  String get freightExchange_riskHigh => _get('freightExchange_riskHigh');

  // ── General §2 additions ────────────────────────────────────────
  String get general_done => _get('general_done');

  static const Map<String, Map<String, String>> _localizedStrings = {
    'ro': {
      'appName': 'Operion', 'appTagline': 'ERP Logistic',
      'auth_login': 'Autentificare', 'auth_email': 'Email', 'auth_password': 'Parolă',
      'auth_loginButton': 'Conectare', 'auth_loggingIn': 'Se conectează...',
      'auth_loginError': 'Email sau parolă incorectă',
      'auth_biometricTitle': 'Deblochează cu date biometrice',
      'auth_biometricHint': 'Autentifică-te folosind amprenta sau recunoașterea facială',
      'auth_sessionExpired': 'Sesiunea a expirat.', 'auth_loggedOut': 'Ai fost deconectat.',
      'auth_logout': 'Deconectare', 'auth_logoutConfirm': 'Ești sigur că vrei să te deconectezi?',
      'auth_forgotPassword': 'Ai uitat parola?',
      'auth_forgotPasswordSent': 'Dacă acest email este înregistrat, veți primi un link de resetare.',
      'nav_home': 'Acasă', 'nav_transports': 'Transporturi', 'nav_documents': 'Documente',
      'nav_messages': 'Mesaje', 'nav_notifications': 'Notificări', 'nav_profile': 'Profil',
      'nav_settings': 'Setări', 'nav_jobs': 'Comenzi', 'nav_fleet': 'Flotă',
      'nav_drivers': 'Șoferi',       'nav_alerts': 'Alerte', 'nav_analytics': 'Analize',
      'nav_map': 'Hartă', 'nav_overview': 'Prezentare generală',
      'nav_fleetTracker': 'Flotă', 'nav_copilot': 'AI Co-Pilot', 'nav_more': 'Mai mult',
      'nav_teams': 'Echipe', 'nav_profitCalculator': 'Calculator Profit',
      'nav_routePlanner': 'Planificator Rută', 'nav_freightExchange': 'Schimb Marfă',
      'nav_documentCenter': 'Centru Documente', 'nav_localDownload': 'Descărcare Locală',
      'moreHub_sectionTitle': 'Funcționalități', 'moreHub_logout': 'Deconectare',
      'nav_reportIssue': 'Raportează problemă',
      'reportIssue_title': 'Raportează problemă',
      'reportIssue_subject': 'Subiect',
      'reportIssue_subjectHint': 'Titlu scurt al problemei',
      'reportIssue_subjectRequired': 'Subiectul este obligatoriu',
      'reportIssue_description': 'Descriere',
      'reportIssue_descriptionHint': 'Descrie problema în detaliu',
      'reportIssue_descriptionRequired': 'Descrierea este obligatorie',
      'reportIssue_submit': 'Trimite',
      'reportIssue_success': 'Problema a fost raportată cu succes',
      'reportIssue_error': 'Eroare la trimiterea raportului',
      'routePlanner_origin': 'Origine', 'routePlanner_originHint': 'Introdu adresa de origine',
      'routePlanner_destination': 'Destinație', 'routePlanner_destinationHint': 'Introdu adresa destinație',
      'routePlanner_stops': 'Opriri', 'routePlanner_addStop': 'Adaugă oprire',
      'routePlanner_noStops': 'Nicio oprire adăugată',
      'routePlanner_noStopsHint': 'Adaugă opriri intermediare pentru a-ți optimiza ruta.',
      'routePlanner_optimize': 'Optimizează ruta', 'routePlanner_stopNumber': 'Oprirea',
      'routePlanner_notice': 'Ruta și timpul sunt estimări bazate pe datele rețelei rutiere.',
      'freightExchange_searchHint': 'Caută după origine, destinație...',
      'freightExchange_origin': 'Origine',
      'freightExchange_destination': 'Destinație',
      'freightExchange_date': 'Data',
      'freightExchange_cargoType': 'Tip marfă',
      'freightExchange_applyFilters': 'Aplică',
      'freightExchange_clearFilters': 'Resetează',
      'freightExchange_empty': 'Nicio cursă găsită',
      'freightExchange_emptyHint': 'Încearcă să ajustezi filtrele sau trage pentru a reîncărca.',
      'freightExchange_loadError': 'Nu s-a putut încărca lista de mărfuri.',
      'freightExchange_loadDetails': 'Detalii cursă',
      'freightExchange_price': 'Preț',
      'freightExchange_weight': 'Greutate',
      'freightExchange_distance': 'Distanță',
      'freightExchange_pickupDate': 'Data încărcării',
      'freightExchange_deadline': 'Termen limită',
      'freightExchange_acceptAndAssign': 'Acceptă și asigneză',
      'freightExchange_selectTransport': 'Selectează transportul',
      'freightExchange_noTransports': 'Niciun transport disponibil',
      'freightExchange_accepting': 'Se acceptă...',
      'freightExchange_accepted': 'Cursa a fost acceptată și asignată',
      'freightExchange_taken': 'Această cursă tocmai a fost luată',
      'freightExchange_takenHint': 'Un alt utilizator a acceptat-o înaintea ta. Lista a fost reîncărcată.',
      'freightExchange_acceptError': 'Nu s-a putut accepta cursa.',
      'freightNegotiation_negotiate': 'Negociază', 'freightNegotiation_title': 'Negociere',
      'freightNegotiation_statusOffered': 'Oferită', 'freightNegotiation_statusCountered': 'Contraofertă',
      'freightNegotiation_statusAccepted': 'Acceptată', 'freightNegotiation_statusRejected': 'Respinsă',
      'freightNegotiation_statusExpired': 'Expirată',
      'freightNegotiation_accept': 'Acceptă', 'freightNegotiation_reject': 'Respinge',
      'freightNegotiation_counter': 'Contraofertă', 'freightNegotiation_counterAmount': 'Sumă contraofertă (EUR)',
      'freightNegotiation_counterSend': 'Trimite contraoferta',
      'freightNegotiation_offline': 'Negocierea necesită o conexiune la internet',
      'freightNegotiation_error': 'Acțiunea de negociere nu a putut fi trimisă',
      'freightNegotiation_you': 'Tu',
      'freightNegotiation_empty': 'Nicio negociere încă — folosește oferta de bază pentru a începe',
      'freightNegotiation_baseOffer': 'Ofertă de bază', 'freightNegotiation_settled': 'Negociere încheiată',
      'freightNegotiation_justNow': 'chiar acum',
      'freightNegotiation_minAgo': 'acum {minutes} min', 'freightNegotiation_hoursAgo': 'acum {hours} h',
      'freightNegotiation_daysAgo': 'acum {days} zile',
      'driver_myDay': 'Ziua mea', 'driver_assignedTransports': 'Transporturi asignate',
      'driver_noTransports': 'Nu ai transporturi asignate', 'driver_vehicleInfo': 'Informații vehicul',
      'driver_expenses': 'Cheltuieli', 'driver_documents': 'Documentele mele',
      'driver_tachograph_title': 'Tahograf',
      'driver_tachograph_note': 'Datele provin din importurile de tahograf efectuate de dispeceri',
      'driver_copilotContextTrip': 'Comanda mea curentă: {origin} → {destination}',
      'driver_copilotContextTransport': 'Transportul meu curent: {loadInfo}',
      'transport_status_planned': 'Planificat', 'transport_status_loading': 'Se încarcă',
      'transport_status_in_progress': 'În curs', 'transport_status_in_transit': 'În tranzit',
      'transport_status_delivered': 'Livrat', 'transport_status_cancelled': 'Anulat',
      'transport_status_overdue': 'Restant', 'transport_status_invoiced': 'Facturat',
      'transport_status_paid': 'Plătit', 'transport_status_maintenance': 'Mentenanță',
      'transport_updateStatus': 'Actualizează status', 'transport_navigate': 'Navighează',
      'transport_route': 'Rută', 'transport_details': 'Detalii transport',
      'document_upload': 'Încarcă document', 'document_capture': 'Fotografiază',
      'document_selectGallery': 'Alege din galerie', 'document_cmr': 'CMR', 'document_pod': 'POD',
      'document_invoice': 'Factură', 'document_other': 'Alt document',
      'document_uploading': 'Se încarcă...', 'document_uploaded': 'Încărcat',
      'document_pending': 'În așteptare', 'document_failed': 'Eroare la încărcare',
      'document_noDocuments': 'Niciun document',
      'expense_new': 'Cheltuială nouă', 'expense_type': 'Tip', 'expense_fuel': 'Carburant',
      'expense_tolls': 'Taxe drum', 'expense_perDiem': 'Diurnă', 'expense_other': 'Altele',
      'expense_amount': 'Sumă', 'expense_date': 'Data', 'expense_receipt': 'Bon fiscal',
      'expense_submit': 'Trimite',
      'vehicle_assigned': 'Vehicul asignat', 'vehicle_plate': 'Număr', 'vehicle_type': 'Tip',
      'vehicle_documents': 'Documente vehicul', 'vehicle_expiry': 'Expiră',
      'message_noMessages': 'Niciun mesaj', 'message_typeMessage': 'Scrie un mesaj...',
      'message_send': 'Trimite', 'message_sending': 'Se trimite...', 'message_sent': 'Trimis',
      'message_you': 'Tu',
      'notification_newAssignment': 'Transport nou asignat', 'notification_scheduleChange': 'Program modificat',
      'notification_newMessage': 'Mesaj nou', 'notification_alert': 'Alertă',
      'dispatcher_overview': 'Prezentare generală', 'dispatcher_activeJobs': 'Comenzi active',
      'dispatcher_activeDrivers': 'Șoferi activi', 'dispatcher_openAlerts': 'Alerte deschise',
      'dispatcher_liveFleet': 'Flotă live', 'dispatcher_approve': 'Aprobă',
      'dispatcher_reject': 'Respinge', 'dispatcher_reassign': 'Reasignare',
      'dispatcher_quickActions': 'Acțiuni rapide',
      'dispatcher_jobDetails': 'Detalii comandă',
      'dispatcher_markDelivered': 'Marchează livrat',
      'dispatcher_messageDriver': 'Trimite mesaj șoferului',
      'dispatcher_reassignConfirm': 'Reasignează la {driver}?',
      'dispatcher_reassignSuccess': 'Transport reasignat cu succes',
      'dispatcher_markDeliveredSuccess': 'Comandă marcată ca livrată',
      'dispatcher_contactDriverPhone': 'Contactați șoferul telefonic',
      'dispatcher_noJobs': 'Nicio comandă găsită',
      'dispatcher_all': 'Toate',
      'dispatcher_driver': 'Șofer',
      'jobs_pending': 'În așteptare',
      'quickAction_approvePending': 'Aprobă comenzile în așteptare',
      'quickAction_approvePendingSubtitle': 'Comenzi care așteaptă aprobare',
      'quickAction_alertCheck': 'Verifică alertele',
      'quickAction_alertCheckSubtitle': 'Deschide inbox-ul de alerte',
      'quickAction_scanDocument': 'Scanează document',
      'quickAction_scanDocumentSubtitle': 'Captură + OCR',
      'notification_approve': 'Aprobă',
      'notification_snooze': 'Amână',
      'notification_view': 'Vezi',
      'general_created': 'Creată',
      'alert_delay': 'Întârziere', 'alert_maintenance': 'Mentenanță',
      'alert_documentExpiry': 'Document expirat', 'alert_compliance': 'Conformitate',
      'alert_noAlerts': 'Nicio alertă',
      'analytics_noData': 'Nicio dată pentru această perioadă',
      'analytics_7d': '7 zile', 'analytics_30d': '30 zile', 'analytics_qtd': 'Trimestrul curent',
      'analytics_ytd': 'Anul curent', 'analytics_custom': 'Personalizat',
      'analytics_customRange': 'Selectează intervalul de date',
      'analytics_revenueTab': 'Venituri', 'analytics_fleetUtilizationTab': 'Utilizare flotă',
      'analytics_driverPerformanceTab': 'Performanță șoferi', 'analytics_invoiceAgingTab': 'Vechime facturi',
      'analytics_export': 'Exportă', 'analytics_exportOffline': 'Exportul necesită o conexiune la internet',
      'analytics_exportStarted': 'Exportul a început — vei fi notificat când e gata',
      'analytics_exportError': 'Exportul a eșuat. Încearcă din nou.',
      'analytics_groupByPeriod': 'Perioadă', 'analytics_groupByClient': 'Client',
      'analytics_groupByRoute': 'Rută', 'analytics_emptyHint': 'Nicio dată pentru acest interval',
      'analytics_status_active': 'Active', 'analytics_status_maintenance': 'În mentenanță',
      'analytics_status_decommissioned': 'Retrase',
      'analytics_driverCol': 'Șofer', 'analytics_tripsCol': 'Comenzi finalizate',
      'analytics_otdCol': 'La timp %', 'analytics_profitPerKmCol': 'Profit/km',
      'analytics_revenueCol': 'Venituri',
      'analytics_aging_current': 'Curente', 'analytics_aging_31_60': '31–60 zile',
      'analytics_aging_61_90': '61–90 zile', 'analytics_aging_overdue': 'Peste 90 zile',
      'analytics_aging_total': 'Total restant',
      'history_tripTitle': 'Istoric comenzi', 'history_routeTitle': 'Istoric rute',
      'history_tripDetails': 'Detalii cursă', 'history_routeDetails': 'Detalii rută',
      'history_netProfit': 'Profit net',
      'history_statusFilter': 'Status', 'history_dateFrom': 'De la', 'history_dateTo': 'Până la',
      'history_clientFilter': 'Client', 'history_export': 'Exportă',
      'history_exportOffline': 'Exportul necesită o conexiune la internet',
      'history_exportStarted': 'Exportul a început — vei fi notificat când e gata',
      'history_exportReady': 'Exportul e gata', 'history_exportFailed': 'Exportul a eșuat',
      'history_emptyTrips': 'Nicio comandă în această perioadă',
      'history_emptyRoutes': 'Nicio rută în această perioadă',
      'history_distanceKm': '{distance} km', 'history_durationMin': '{duration} min',
      'history_loadingMore': 'Se încarcă mai multe...', 'history_noMore': 'Nu mai sunt date',
      'history_exportNoJobs': 'Niciun export în curs', 'history_exportPolling': 'Se generează exportul...',
      'globalSearch_title': 'Căutare globală', 'globalSearch_hint': 'Caută comenzi, clienți, șoferi, camioane, documente...',
      'globalSearch_empty': 'Niciun rezultat', 'globalSearch_minChars': 'Tastează cel puțin 2 caractere',
      'globalSearch_trips': 'Comenzi', 'globalSearch_clients': 'Clienți',
      'globalSearch_drivers': 'Șoferi', 'globalSearch_trucks': 'Camioane',
      'globalSearch_documents': 'Documente', 'globalSearch_more': 'Încă {count}',
      'globalSearch_openSearch': 'Căutare globală',
      'records_tripHistory': 'Istoric comenzi', 'records_routeHistory': 'Istoric rute',
      'nav_invoicing': 'Facturi', 'nav_maintenance': 'Mentenanță',
      'invoicing_title': 'Factură', 'invoicing_cached': 'Se afișează date din cache',
      'invoicing_searchHint': 'Caută facturi...',
      'invoicing_emptyTitle': 'Nicio factură încă',
      'invoicing_emptyHint': 'Atinge + pentru a crea prima factură',
      'invoicing_total': 'Total', 'invoicing_due': 'Scadență',
      'invoicing_statusAll': 'Toate', 'invoicing_statusDraft': 'Ciornă',
      'invoicing_statusFinalized': 'Finalizată', 'invoicing_statusXml': 'XML generat',
      'invoicing_statusPaid': 'Plătită', 'invoicing_statusCancelled': 'Anulată',
      'invoicing_stepperTitle': 'Status', 'invoicing_stepDraft': 'Ciornă',
      'invoicing_stepFinalized': 'Finalizată', 'invoicing_stepXml': 'e-Factura XML',
      'invoicing_stepPaid': 'Plătită',
      'invoicing_stepCancelled': 'Anulată',
      'invoicing_client': 'Client', 'invoicing_clientHint': 'Selectează un client',
      'invoicing_clientSearch': 'Caută clienți...',
      'invoicing_clientRequired': 'Selectează un client înainte de salvare',
      'invoicing_trip': 'Comandă', 'invoicing_tripShort': 'Comanda',
      'invoicing_tripHint': 'Selectează o comandă (opțional)',
      'invoicing_tripSearch': 'Caută comenzi...',
      'invoicing_noTrips': 'Nicio comandă găsită', 'invoicing_noClients': 'Niciun client găsit',
      'invoicing_lineItems': 'Linii de factură', 'invoicing_addLine': 'Adaugă linie',
      'invoicing_noLines': 'Nicio linie',
      'invoicing_noLinesHint': 'Adaugă prima linie pentru a construi factura',
      'invoicing_unnamedLine': 'Linie fără descriere', 'invoicing_vatShort': 'TVA',
      'invoicing_subtotal': 'Subtotal', 'invoicing_vat': 'TVA',
      'invoicing_lineItem': 'Linie de factură', 'invoicing_description': 'Descriere',
      'invoicing_descriptionRequired': 'Descrierea este obligatorie',
      'invoicing_quantity': 'Cantitate', 'invoicing_quantityRequired': 'Introdu o cantitate validă',
      'invoicing_unitPrice': 'Preț unitar', 'invoicing_priceRequired': 'Introdu un preț',
      'invoicing_discountPct': 'Reducere %', 'invoicing_discountAmount': 'Valoare reducere',
      'invoicing_vatRate': 'Cotă TVA (%)', 'invoicing_invoiceNumber': 'Nr. factură',
      'invoicing_saveDraft': 'Salvează ciorna', 'invoicing_finalize': 'Finalizează',
      'invoicing_generateXml': 'Generează XML e-Factura',
      'invoicing_markPaid': 'Marchează plătită', 'invoicing_noAction': 'Nicio acțiune suplimentară',
      'invoicing_cancel': 'Anulează factura', 'invoicing_viewPdf': 'Vezi PDF',
      'invoicing_pdfTitle': 'PDF factură',
      'invoicing_pdfError': 'PDF-ul nu poate fi afișat pe acest dispozitiv',
      'invoicing_savedDraft': 'Ciornă salvată',
      'invoicing_savedOffline': 'Salvată offline — se va sincroniza când revii online',
      'invoicing_queuedOffline': 'Acțiune pusă în coadă — se va sincroniza când revii online',
      'invoicing_requiresConnection': 'Această acțiune necesită o conexiune la internet',
      'invoicing_biometricReason': 'Autentifică-te pentru a confirma această acțiune asupra facturii',
      'invoicing_biometricDenied': 'Autentificare anulată — acțiunea nu a fost finalizată',
      'invoicing_finalizedOk': 'Factura a fost finalizată',
      'invoicing_xmlGeneratedOk': 'XML e-Factura generat',
      'invoicing_paidOk': 'Factura a fost marcată ca plătită',
      'invoicing_cancelledOk': 'Factura a fost anulată',
      'invoicing_cmrTitle': 'Document CMR', 'invoicing_cmrSender': 'Expeditor',
      'invoicing_cmrSenderName': 'Nume expeditor',
      'invoicing_cmrSenderNameRequired': 'Numele expeditorului este obligatoriu',
      'invoicing_cmrSenderAddress': 'Adresa expeditorului',
      'invoicing_cmrSenderAddressRequired': 'Adresa expeditorului este obligatorie',
      'invoicing_cmrConsignee': 'Destinatar',
      'invoicing_cmrFromTrip': 'Completat pe server din datele comenzii',
      'invoicing_cmrCarrier': 'Transportator', 'invoicing_cmrCarrierName': 'Nume transportator',
      'invoicing_cmrCarrierLicense': 'Licență transportator', 'invoicing_cmrGoods': 'Marfă',
      'invoicing_cmrInstructions': 'Instrucțiuni', 'invoicing_cmrLanguage': 'Limbă',
      'invoicing_cmrCopies': 'Copii', 'invoicing_cmrIncludeStamps': 'Include ștampile',
      'invoicing_cmrRemarks': 'Observații', 'invoicing_cmrSignatures': 'Semnături',
      'invoicing_cmrClearSignature': 'Șterge semnătura', 'invoicing_cmrSave': 'Salvează CMR',
      'invoicing_cmrSaved': 'CMR salvat',
      'maintenance_costTrend': 'Evoluția costurilor', 'maintenance_schedules': 'Programări',
      'maintenance_overdueOnly': 'Doar restante',
      'maintenance_emptyTitle': 'Nicio programare de mentenanță',
      'maintenance_emptyHint': 'Atinge + pentru a adăuga o programare',
      'maintenance_byType': 'Pe categorii', 'maintenance_overdue': 'RESTANT',
      'maintenance_every': 'La fiecare', 'maintenance_months': 'luni',
      'maintenance_nextDue': 'Următoarea scadență', 'maintenance_lastKm': 'Ultima realizată la',
      'maintenance_addSchedule': 'Adaugă programare', 'maintenance_truck': 'Camion',
      'maintenance_truckRequired': 'Selectează un camion',
      'maintenance_type': 'Tip mentenanță', 'maintenance_typeRequired': 'Introdu tipul de mentenanță',
      'maintenance_intervalKm': 'Interval (km)', 'maintenance_intervalMonths': 'Interval (luni)',
      'maintenance_fixedExpiry': 'Termen fix', 'maintenance_fixedExpiryHint': 'Opțional — alege o dată',
      'maintenance_scheduleAdded': 'Programarea a fost adăugată',
      'ocr_results': 'Rezultate OCR',
      'ocr_processing': 'Procesare OCR în fundal. Rezultatele vor apărea mai târziu.',
      'ocr_confidence': '{percent}% încredere',
      'general_cancel': 'Anulează', 'general_confirm': 'Confirmă', 'general_save': 'Salvează',
      'general_delete': 'Șterge', 'general_edit': 'Editează', 'general_retry': 'Reîncearcă',
      'general_loading': 'Se încarcă...', 'general_error': 'A apărut o eroare',
      'general_noInternet': 'Fără conexiune la internet', 'general_offline': 'Ești offline',
      'general_lastUpdated': 'Ultima actualizare', 'general_minAgo': 'acum {count} min',
      'general_justNow': 'chiar acum', 'general_hourAgo': 'acum o oră',
      'general_hoursAgo': 'acum {count} ore', 'general_pendingSync': 'Se așteaptă sincronizarea',
      'general_comingSoon': 'În curând',
      'general_comingSoonDescription': 'Această funcție va fi disponibilă într-o actualizare viitoare',
      'general_openDesktop': 'Deschide pe desktop', 'general_yes': 'Da', 'general_no': 'Nu',
      'settings_language': 'Limbă', 'settings_languageRo': 'Română', 'settings_languageEn': 'English',
      'settings_appearance': 'Aspect',
      'settings_theme': 'Temă', 'settings_themeSystem': 'Sistem', 'settings_themeLight': 'Luminos',
      'settings_themeDark': 'Întunecat',       'settings_appVersion': 'Versiune aplicație',
      'nav_teamsManagement': 'Gestionare Echipă', 'nav_tachograph': 'Tahograf',
      'settings_saved': 'Setările au fost salvate',
      'settings_saveFailed': 'Nu s-au putut salva setările',
      'settings_saving': 'Se salvează...', 'settings_save': 'Salvează',
      'settings_companyProfile': 'Profilul companiei',
      'settings_legalName': 'Denumire legală', 'settings_vatNumber': 'CUI / TVA',
      'settings_address': 'Adresă', 'settings_invoiceFooter': 'Text final factură',
      'settings_smtp': 'Configurare SMTP', 'settings_smtpServer': 'Server SMTP',
      'settings_smtpPort': 'Port SMTP', 'settings_smtpUser': 'Utilizator SMTP',
      'settings_smtpPassword': 'Parolă SMTP',
      'settings_configuredPlaceholder': '•••• configurat',
      'settings_sendTestEmail': 'Trimite email de test',
      'settings_testEmailSent': 'Emailul de test a fost trimis',
      'settings_testEmailFailed': 'Emailul de test a eșuat',
      'settings_tracking': 'Furnizor de urmărire',
      'settings_trackingApiKey': 'Cheie API urmărire',
      'settings_trackingNone': 'Niciunul',
      'settings_maintenanceThresholds': 'Praguri de mentenanță',
      'settings_maintenanceAlertDays': 'Alertă mentenanță (zile)',
      'settings_tachoWarningDays': 'Avertizare tahograf (zile)',
      'settings_tachoCriticalDays': 'Critic tahograf (zile)',
      'settings_notifications': 'Preferințe notificări',
      'settings_notifCritical': 'Critice', 'settings_notifWarning': 'Avertizări',
      'settings_notifInfo': 'Informative', 'settings_quietHours': 'Ore de liniște',
      'settings_dataUsage': 'Utilizare date',
      'settings_wifiOnlyLargeSyncs': 'Doar pe Wi-Fi pentru sincronizări mari',
      'settings_wifiOnlyLargeSyncsHint': 'Blochează sincronizările mari și încărcările pe date mobile',
      'settings_biometricLock': 'Blocare biometrică',
      'settings_biometricUnlock': 'Deblocare cu date biometrice',
      'settings_biometricUnlockHint': 'Arată butonul biometric la autentificare',
      'settings_requireFinancial': 'Cerință pentru acțiuni financiare',
      'settings_requireFinancialHint': 'Solicită confirmare biometrică înainte de acțiunile financiare sensibile',
      'wifi_only_message': 'Wi-Fi-only este activat — conectează-te la o rețea Wi-Fi pentru această acțiune',
      'team_inviteTitle': 'Invită un membru', 'team_inviteEmail': 'Email',
      'team_inviteEmailRequired': 'Emailul este obligatoriu',
      'team_inviteEmailInvalid': 'Introdu o adresă de email validă',
      'team_inviteRole': 'Rol', 'team_inviteBtn': 'Invită', 'team_inviting': 'Se trimite...',
      'team_memberDetails': 'Detalii membru',
      'team_inviteSent': 'Invitația a fost trimisă',
      'team_inviteFailed': 'Invitația a eșuat',
      'team_requiresConnection': 'Această acțiune necesită o conexiune la internet',
      'team_notPermitted': 'Nu ai permisiunea de a gestiona echipa',
      'team_deactivateTitle': 'Dezactivează utilizatorul',
      'team_deactivateMessage': 'Aceasta va revoca imediat sesiunile mobile ale lui {name} și îi va deconecta toate dispozitivele',
      'team_deactivate': 'Dezactivează',
      'team_deactivated': 'Utilizatorul a fost dezactivat',
      'team_actionFailed': 'Acțiunea a eșuat',
      'team_roleUpdated': 'Rolul a fost actualizat',
      'team_emptyTitle': 'Niciun membru încă',
      'team_emptyHint': 'Folosește + pentru a invita primul membru',
      'team_cached': 'Se afișează date din cache',
      'team_active': 'Activ', 'team_inactive': 'Inactiv',
      'team_moreActions': 'Mai multe acțiuni',
      'tacho_selectDriverTitle': 'Alege șoferul',
      'tacho_selectDriver': 'Selectează un șofer',
      'tacho_driverSearch': 'Caută șoferi...',
      'tacho_noDrivers': 'Niciun șofer găsit',
      'tacho_noDriverSelected': 'Selectează întâi un șofer',
      'tacho_importFile': 'Importă fișier .ddd',
      'tacho_importing': 'Se importă...',
      'tacho_processing': 'Se procesează cardul...',
      'tacho_uploadFailed': 'Importul a eșuat',
      'tacho_requiresConnection': 'Importul necesită o conexiune la internet',
      'tacho_wifiOnly': 'Wi-Fi-only este activat — conectează-te la Wi-Fi pentru a importa',
      'tacho_imported': 'Card importat',
      'tacho_empty': 'Nicio conformitate de importat',
      'tacho_emptyHint': 'Importă un fișier .ddd sau .esm de la tahograful șoferului',
      'tacho_complianceTitle': 'Rezumat conformitate',
      'tacho_weeklyDriving': 'Conducere săptămânală',
      'tacho_overLimit': 'Peste limita săptămânală de conducere',
      'tacho_days': 'Zile', 'tacho_violations': 'Avertizări',
      'tacho_noViolations': 'Nicio încălcare detectată',
      'ai_title': 'AI Co-Pilot', 'ai_emptyStateMessage': 'Întreabă-mă orice despre flota ta',
      'ai_emptyStatePrompt': 'Încearcă: "Arată camioanele disponibile"',
      'ai_clarifyPlaceholder': 'Scrie răspunsul...', 'ai_newConversation': 'Conversație nouă',
      'ai_placeholder': 'Scrie o comandă sau întrebare...',
      'ai_confirmTitle': 'Confirmă acțiunea',
      'ai_confirmMessage': 'Operion AI propune următoarea acțiune:',
      'copilot_level3_title': 'Nivelul 3 — Tastează confirmarea pentru a continua',
      'copilot_level3_warning': 'Această acțiune este IREVERSIBILĂ. Tastează fraza de confirmare pentru a continua.',
      'copilot_level3_hint': 'Tastează fraza de confirmare...',
      'copilot_level3_phrase': 'Tastează: "{phrase}"',
      'copilot_maintenanceCapture': 'Înregistrează mentenanță',
      'copilot_maintenanceEmpty': 'Detalii mentenanță din solicitare',
      'copilot_maintenanceSelectTruck': 'Selectează camionul',
      'copilot_maintenanceConfirm': 'Pre-completează și confirmă',
      'copilot_maintenanceSaved': 'Înregistrarea de mentenanță a fost salvată',
      'profile_personalInfo': 'Informații personale',
      'profile_driverInfo': 'Informații șofer',
      'profile_quickLinks': 'Linkuri rapide',
      'profile_licenseNumber': 'Număr permis',
      'profile_licenseCategory': 'Categorie permis',
      'profile_licenseExpiry': 'Expirare permis',
      'profile_phone': 'Telefon',
      'profile_displayName': 'Nume afișat',
      'profile_noDriverInfo': 'Nu există informații despre șofer',
      'profile_documentLicense': 'Permis de conducere',
      'profile_documentPassport': 'Pașaport',
      'profile_documentAdr': 'Certificat ADR',
      'profile_selectCamera': 'Cameră',
      'profile_selectGallery': 'Galerie',
      'profile_noDocuments': 'Niciun document încărcat',
      'profile_uploadSuccess': 'Document încărcat cu succes',
      'profile_uploadError': 'Încărcare eșuată',
      'driverOverview_emptyState': 'Nicio cursă activă',
      'driverOverview_emptyStateSubtitle': 'Nu ai niciun transport asignat momentan.',
      'driverOverview_etaUnavailable': 'ETA indisponibilă',
      'transport_statusUpdated': 'Status actualizat',
      'transport_eta': 'ETA',
      'transport_elapsedTime': 'Timp scurs',
      'routeShare_noData': 'Nicio rută',
      'routeShare_noDataSubtitle': 'Informațiile de rută nu sunt disponibile încă pentru acest transport.',
      'routeShare_distance': 'Distanță',
      'routeShare_estimatedTime': 'Timp estimat',
      'routeShare_offRoute': 'Pari a fi în afara rutei',
      'routeShare_backgroundBanner': 'Navigarea se va întrerupe când aplicația este în fundal',
      'routeShare_permissionDenied': 'Accesul la locație este refuzat. Actualizările poziției nu sunt disponibile.',
      'routeShare_fgNotificationTitle': '{instruction}',
      'routeShare_fgNotificationBody': '{distance} · {eta} rămase',
      'routeShare_fgChannelName': 'Navigare Operion',
      'transport_action_startLoading': 'Începe încărcarea',
      'transport_action_depart': 'Pleacă',
      'transport_action_markDelivered': 'Marchează ca livrat',
      'transport_action_reportDelay': 'Raportează întârzierea',
      'transport_action_noActions': 'Nicio acțiune disponibilă',
      'profitCalculator_title': 'Calculator profit',
      'profitCalculator_price': 'Preț',
      'profitCalculator_fuelCost': 'Cost carburant',
      'profitCalculator_tollCost': 'Cost taxe drum',
      'profitCalculator_driverCost': 'Cost șofer',
      'profitCalculator_extraCosts': 'Costuri extra',
      'profitCalculator_calculate': 'Calculează',
      'profitCalculator_totalCosts': 'Costuri totale',
      'profitCalculator_profit': 'Profit',
      'profitCalculator_profitMargin': 'Marjă profit',
      'profitCalculator_currencySymbol': 'RON',
      'teams_filterAll': 'Toți',
      'teams_filterAvailable': 'Disponibil',
      'teams_filterDriving': 'Conduce',
      'teams_filterOff': 'Oprit',
      'teams_placeholder': 'Lista șoferilor va apărea aici când este conectată la server.',
      'teams_licenseNumber': 'Număr permis',
      'teams_licenseCategory': 'Categorie permis',
      'teams_licenseExpiry': 'Expirare permis',
      'teams_medicalExpiry': 'Expirare medicală',
      'teams_assignedVehicle': 'Vehicul asignat',
      'teams_assignedTransport': 'Transport asignat',
      'teams_licenseValid': 'Valid',
      'teams_licenseExpiringSoon': 'Expiră în curând',
      'teams_licenseExpired': 'Expirat',
      'teams_notAssigned': 'Neasignat',
      'teams_detailLoadError': 'Nu s-au putut încărca detaliile șoferului.',

      // ── Document Center ──
      'documentCenter_title': 'Centru documente',
      'documentCenter_documents': 'Documente',
      'documentCenter_automation': 'Automatizare',
      'documentCenter_ocrTitle': 'Captură documente OCR',
      'documentCenter_ocrDescription': 'Fotografiază un document pentru a extrage automat câmpurile.',
      'documentCenter_capturePhoto': 'Fotografiază',
      'documentCenter_uploadConfirmed': 'Încărcare confirmată, se procesează...',
      'documentCenter_uploadInProgress': 'Se încarcă...',
      'documentCenter_uploadError': 'Încărcare eșuată. Încearcă din nou.',
      'documentCenter_processingHint': 'Documentul este procesat în cloud. Rezultatele vor apărea în Descărcare Locală.',
      'documentCenter_captureAnother': 'Fotografiază alt document',
      'documentCenter_documentsEmpty': 'Toate documentele companiei vor apărea aici.',
      'documentCenter_documentsError': 'Nu s-a putut încărca lista de documente.',

      // ── Local Download ──
      'localDownload_title': 'Descărcare locală',
      'localDownload_selectCategory': 'Selectează categoria',
      'localDownload_download': 'Descarcă',
      'localDownload_categoryDocuments': 'Documente',
      'localDownload_categoryInvoices': 'Facturi',
      'localDownload_categoryReceipts': 'Chitanțe',
      'localDownload_categoryOcrResults': 'Rezultate OCR',
      'localDownload_categoryTripHistory': 'Istoric curse',
      'localDownload_dateFrom': 'De la',
      'localDownload_dateTo': 'Până la',
      'localDownload_progress': 'Se descarcă...',
      'localDownload_complete': 'Descărcare completă',
      'localDownload_downloadAll': 'Descarcă toate',
      'localDownload_manifestEmpty': 'Niciun fișier de descărcat',
      'localDownload_manifestError': 'Nu s-a putut încărca lista de fișiere.',
      'nav_records': 'Înregistrări',
      'records_searchHint': 'Caută în înregistrări...',
      'records_emptyTitle': 'Nicio înregistrare disponibilă',
      'records_emptyHint': 'Nicio înregistrare găsită',
      'records_fleet': 'Flotă',
      'records_drivers': 'Șoferi',
      'records_clients': 'Clienți',
      'fleet_cached': 'Se afișează date din cache',
      'fleet_searchHint': 'Caută după număr, marcă sau model...',
      'fleet_emptyTitle': 'Niciun camion încă',
      'fleet_emptyHint': 'Apasă + pentru a adăuga primul camion',
      'fleet_statusActive': 'Activ',
      'fleet_statusMaintenance': 'În service',
      'fleet_statusDecommissioned': 'Inactiv',
      'fleet_edit': 'Editare',
      'fleet_decommission': 'Scoatere din uz',
      'fleet_decommissionConfirm': 'Scoaterea din uz este ireversibilă. Continui?',
      'fleet_overview': 'Prezentare',
      'fleet_maintenance': 'Mentenanță',
      'fleet_documents': 'Documente',
      'fleet_assignments': 'Atribuiri',
      'fleet_vin': 'VIN',
      'fleet_year': 'An',
      'fleet_health': 'Stare',
      'fleet_currentDriver': 'Șofer actual',
      'fleet_noMaintenance': 'Nicio înregistrare de mentenanță',
      'fleet_recordWorkHint': 'Folosește butonul + pentru a înregistra lucrări',
      'fleet_documentsPlaceholder': 'Integrarea Document Center sosește într-o fază ulterioară',
      'fleet_noDocuments': 'Niciun document',
      'fleet_assignmentsNote': 'Atribuirile sunt gestionate din fluxul de dispecerizare',
      'fleet_editTitle': 'Detalii camion',
      'fleet_plate': 'Număr înmatriculare',
      'fleet_plateRequired': 'Numărul de înmatriculare este obligatoriu',
      'fleet_brand': 'Marcă',
      'fleet_brandRequired': 'Marca este obligatorie',
      'fleet_model': 'Model',
      'fleet_modelRequired': 'Modelul este obligatoriu',
      'fleet_recordWork': 'Înregistrează lucrare',
      'fleet_date': 'Data',
      'fleet_category': 'Categorie',
      'fleet_cost': 'Cost',
      'fleet_costRequired': 'Introdu un cost valid',
      'fleet_vendor': 'Furnizor',
      'fleet_notes': 'Note',
      'fleet_categoryOil': 'Schimb ulei',
      'fleet_categoryTires': 'Anvelope',
      'fleet_categoryBrakes': 'Frâne',
      'fleet_categoryEngine': 'Motor',
      'fleet_categoryBodywork': 'Caroserie',
      'fleet_categoryInspection': 'Inspecție',
      'fleet_categoryOther': 'Altele',
      'teams_filterExpiring': 'Expiră',
      'teams_expired': 'EXPIRAT',
      'teams_daysShort': 'z',
      'teams_editDriver': 'Editare șofer',
      'teams_overview': 'Prezentare',
      'teams_compliance': 'Conformitate',
      'teams_tacho': 'Tahograf',
      'teams_assignments': 'Atribuiri',
      'teams_renew': 'Reînnoire',
      'teams_adrExpiry': 'Expirare certificat ADR',
      'teams_expiryWindow': 'Fereastră de expirare:',
      'teams_weeklyDriving': 'Conducere săptămânală',
      'teams_weeklyLimit': 'Limită săptămânală:',
      'teams_weeklyOverLimit': 'Peste limita săptămânală de conducere',
      'teams_tachoEmpty': 'Nicio dată de tahograf disponibilă',
      'teams_assignmentsNote': 'Atribuirile sunt gestionate din fluxul de dispecerizare',
      'teams_editTitle': 'Detalii șofer',
      'teams_phone': 'Telefon',
      'teams_email': 'Email',
      'tacho_driving': 'Conducere',
      'tacho_working': 'Lucru',
      'tacho_rest': 'Odihnă',
      'tacho_availability': 'Disponibil',
      'nav_clients': 'Clienți',
      'clients_cached': 'Se afișează date din cache',
      'clients_searchHint': 'Caută clienți...',
      'clients_emptyTitle': 'Niciun client încă',
      'clients_emptyHint': 'Apasă + pentru a adăuga primul client',
      'clients_paymentTerms': 'Termeni de plată',
      'clients_daysShort': 'zile',
      'clients_active': 'Activ',
      'clients_inactive': 'Inactiv',
      'clients_editTitle': 'Detalii client',
      'clients_name': 'Nume',
      'clients_nameRequired': 'Numele este obligatoriu',
      'clients_vatNumber': 'Cod fiscal',
      'clients_address': 'Adresă',
      'clients_details': 'Detalii',
      'clients_contacts': 'Contacte',
      'clients_invoices': 'Facturi',
      'clients_trips': 'Curse',
      'clients_rating': 'Rating',
      'clients_noPermission': 'Nu ai permisiunea de a gestiona contactele',
      'clients_addContact': 'Adaugă contact',
      'clients_noContacts': 'Niciun contact încă',
      'clients_addContactHint': 'Adaugă primul contact pentru acest client',
      'clients_recentInvoices': 'Facturi recente:',
      'clients_recentTrips': 'Curse recente:',
      'clients_invoicesPlaceholder': 'Facturile sosesc într-o fază ulterioară',
      'clients_invoicesPlaceholderHint': 'Istoricul facturilor va fi conectat în Faza 3',
      'clients_tripsPlaceholder': 'Cursele sosesc într-o fază ulterioară',
      'clients_tripsPlaceholderHint': 'Istoricul curselor va fi conectat în Faza 2',
      'clients_noInvoices': 'Nicio factură',
      'clients_noInvoicesHint': 'Facturile pentru acest client vor apărea aici.',
      'clients_noTrips': 'Nicio cursă',
      'clients_noTripsHint': 'Cursele pentru acest client vor apărea aici.',
      'clients_editContactTitle': 'Detalii contact',
      'clients_contactName': 'Nume contact',
      'clients_contactNameRequired': 'Numele contactului este obligatoriu',
      'clients_contactRole': 'Rol',
      'clients_contactPhone': 'Telefon',
      'clients_contactEmail': 'Email',
      'clients_merge': 'Fuzionează clienți',
      'clients_mergeTarget': 'Client țintă',
      'clients_mergeSources': 'Clienți de fuzionat',
      'clients_mergeTypeConfirm': 'Scrie exact numele țintei pentru confirmare',
      'clients_mergeOffline': 'Fuzionarea necesită o conexiune la internet',
      'clients_mergeBtn': 'Fuzionează',
      'clients_mergeSummary': 'Totaluri estimate după fuziune',
      'clients_tripsShort': 'Curse:',
      'clients_invoicesShort': 'Facturi:',
      'clients_contactsShort': 'Contacte:',
      'localDownload_saved': 'Salvat pe dispozitiv',
      // ── §2 Feature-parity ────────────────────────────────────────
      'dispatcher_revenueTrend': 'Tendința veniturilor',
      'dispatcher_activityFeed': 'Activitate recentă',
      'dispatcher_activityEmpty': 'Nicio activitate recentă',
      'routePlanner_profile': 'Profil de rutare',
      'routePlanner_profileTruck': 'Camion',
      'routePlanner_profileCar': 'Autoturism',
      'routePlanner_profilePedestrian': 'Pieton',
      'routePlanner_avoidCountries': 'Țări de evitat',
      'routePlanner_avoidCountriesHint': 'Selectează țările pe care ruta ar trebui să le evite',
      'routePlanner_selectCountries': 'Selectează țări',
      'documentCenter_searchHint': 'Caută documente...',
      'documentCenter_allCategories': 'Toate',
      'documentCenter_versions': 'Versiuni',
      'documentCenter_noVersions': 'Nicio versiune',
      'documentCenter_versionNumber': 'Versiunea',
      'documentCenter_uploadedBy': 'Încărcat de',
      'documentCenter_previewUnavailable': 'Previzualizarea nu este disponibilă pentru acest tip de document',
      'jobs_viewList': 'Listă',
      'jobs_viewKanban': 'Kanban',
      'jobs_viewTimeline': 'Cronologie',
      'jobs_kanbanHint': 'Apasă lung și trage cardurile între coloane',
      'jobs_kanbanEmpty': 'Fără comenzi',
      'jobs_moved': 'Comandă mutată',
      'jobs_undo': 'Anulează',
      'jobs_moveFailed': 'Mutarea a eșuat. Comanda a fost restabilită.',
      'jobs_timelineNoDates': 'Comenzile fără date de început/sfârșit sunt afișate ca marcaje',
      'jobs_timelineUnassigned': 'Fără vehicul',
      'freightExchange_moreFilters': 'Mai multe filtre',
      'freightExchange_advancedSearch': 'Căutare avansată',
      'freightExchange_pickupFrom': 'Încărcare de la',
      'freightExchange_pickupTo': 'Încărcare până la',
      'freightExchange_weightMin': 'Greutate min (kg)',
      'freightExchange_weightMax': 'Greutate max (kg)',
      'freightExchange_trailerType': 'Tip trailer',
      'freightExchange_priceMin': 'Preț min',
      'freightExchange_priceMax': 'Preț max',
      'freightExchange_savedSearches': 'Căutări salvate',
      'freightExchange_saveCurrentSearch': 'Salvează căutarea curentă',
      'freightExchange_savedSearchLabel': 'Nume căutare',
      'freightExchange_savedSearchLabelHint': 'ex. Berlin → București',
      'freightExchange_searchSaved': 'Căutare salvată',
      'freightExchange_saveSearchError': 'Nu s-a putut salva căutarea',
      'freightExchange_noSavedSearches': 'Nicio căutare salvată',
      'freightExchange_deleteSearch': 'Șterge căutarea',
      'freightExchange_deleteSearchConfirm': 'Sigur doriți să ștergeți această căutare salvată?',
      'freightExchange_runSearch': 'Rulează',
      'freightExchange_evaluate': 'Evaluează',
      'freightExchange_evaluation': 'Evaluare încărcătură',
      'freightExchange_evaluationError': 'Evaluarea a eșuat',
      'freightExchange_estimatedRevenue': 'Venit estimat',
      'freightExchange_expectedProfit': 'Profit estimat',
      'freightExchange_profitMargin': 'Marjă',
      'freightExchange_fuelCost': 'Combustibil',
      'freightExchange_tollCost': 'Taxe drum',
      'freightExchange_driverSalary': 'Șofer',
      'freightExchange_deadheadKm': 'Drum gol',
      'freightExchange_durationHours': 'Durată',
      'freightExchange_riskScore': 'Risc',
      'freightExchange_vehicleCompatibility': 'Compatibilitate vehicul',
      'freightExchange_vehicleCompatible': 'Vehicul compatibil',
      'freightExchange_vehicleIncompatible': 'Vehicul incompatibil',
      'freightExchange_riskLow': 'Scăzut',
      'freightExchange_riskMedium': 'Mediu',
      'freightExchange_riskHigh': 'Ridicat',
      'general_done': 'Gata',
    },
    'en': {
      'appName': 'Operion', 'appTagline': 'Logistics ERP',
      'auth_login': 'Sign In', 'auth_email': 'Email', 'auth_password': 'Password',
      'auth_loginButton': 'Sign In', 'auth_loggingIn': 'Signing in...',
      'auth_loginError': 'Incorrect email or password',
      'auth_biometricTitle': 'Unlock with Biometrics',
      'auth_biometricHint': 'Authenticate using fingerprint or face recognition',
      'auth_sessionExpired': 'Your session has expired.', 'auth_loggedOut': 'You have been signed out.',
      'auth_logout': 'Sign Out', 'auth_logoutConfirm': 'Are you sure you want to sign out?',
      'auth_forgotPassword': 'Forgot password?',
      'auth_forgotPasswordSent': "If this email is registered, you'll receive a reset link.",
      'nav_home': 'Home', 'nav_transports': 'Transports', 'nav_documents': 'Documents',
      'nav_messages': 'Messages', 'nav_notifications': 'Notifications', 'nav_profile': 'Profile',
      'nav_settings': 'Settings', 'nav_jobs': 'Jobs', 'nav_fleet': 'Fleet',       'nav_drivers': 'Drivers',
      'nav_alerts': 'Alerts', 'nav_analytics': 'Analytics',
      'nav_map': 'Map', 'nav_overview': 'Overview',
      'nav_fleetTracker': 'Fleet Tracker', 'nav_copilot': 'AI Copilot', 'nav_more': 'More',
      'nav_teams': 'Teams', 'nav_profitCalculator': 'Profit Calculator',
      'nav_routePlanner': 'Route Planner', 'nav_freightExchange': 'Freight Exchange',
      'nav_documentCenter': 'Document Center', 'nav_localDownload': 'Local Download',
      'moreHub_sectionTitle': 'Features', 'moreHub_logout': 'Sign Out',
      'nav_reportIssue': 'Report Issue',
      'reportIssue_title': 'Report Issue',
      'reportIssue_subject': 'Subject',
      'reportIssue_subjectHint': 'Brief issue title',
      'reportIssue_subjectRequired': 'Subject is required',
      'reportIssue_description': 'Description',
      'reportIssue_descriptionHint': 'Describe the issue in detail',
      'reportIssue_descriptionRequired': 'Description is required',
      'reportIssue_submit': 'Submit',
      'reportIssue_success': 'Issue reported successfully',
      'reportIssue_error': 'Error submitting report',
      'routePlanner_origin': 'Origin', 'routePlanner_originHint': 'Enter origin address',
      'routePlanner_destination': 'Destination', 'routePlanner_destinationHint': 'Enter destination address',
      'routePlanner_stops': 'Stops', 'routePlanner_addStop': 'Add Stop',
      'routePlanner_noStops': 'No stops added',
      'routePlanner_noStopsHint': 'Add intermediate stops to optimize your route.',
      'routePlanner_optimize': 'Optimize Route', 'routePlanner_stopNumber': 'Stop',
      'routePlanner_notice': 'Route and timing are estimates based on road network data.',
      'freightExchange_searchHint': 'Search by origin, destination...',
      'freightExchange_origin': 'Origin',
      'freightExchange_destination': 'Destination',
      'freightExchange_date': 'Date',
      'freightExchange_cargoType': 'Cargo type',
      'freightExchange_applyFilters': 'Apply',
      'freightExchange_clearFilters': 'Clear',
      'freightExchange_empty': 'No loads found',
      'freightExchange_emptyHint': 'Try adjusting your filters or pull to refresh.',
      'freightExchange_loadError': 'Could not load the load board.',
      'freightExchange_loadDetails': 'Load details',
      'freightExchange_price': 'Price',
      'freightExchange_weight': 'Weight',
      'freightExchange_distance': 'Distance',
      'freightExchange_pickupDate': 'Pickup date',
      'freightExchange_deadline': 'Deadline',
      'freightExchange_acceptAndAssign': 'Accept & Assign',
      'freightExchange_selectTransport': 'Select transport',
      'freightExchange_noTransports': 'No transports available',
      'freightExchange_accepting': 'Accepting...',
      'freightExchange_accepted': 'Load accepted and assigned',
      'freightExchange_taken': 'This load was just taken',
      'freightExchange_takenHint': 'Another user accepted it first. The list has been refreshed.',
      'freightExchange_acceptError': 'Could not accept the load.',
      'freightNegotiation_negotiate': 'Negotiate', 'freightNegotiation_title': 'Negotiation',
      'freightNegotiation_statusOffered': 'Offered', 'freightNegotiation_statusCountered': 'Countered',
      'freightNegotiation_statusAccepted': 'Accepted', 'freightNegotiation_statusRejected': 'Rejected',
      'freightNegotiation_statusExpired': 'Expired',
      'freightNegotiation_accept': 'Accept', 'freightNegotiation_reject': 'Reject',
      'freightNegotiation_counter': 'Counter', 'freightNegotiation_counterAmount': 'Counter amount (EUR)',
      'freightNegotiation_counterSend': 'Send counter',
      'freightNegotiation_offline': 'Negotiation requires an internet connection',
      'freightNegotiation_error': 'Could not send the negotiation action',
      'freightNegotiation_you': 'You',
      'freightNegotiation_empty': 'No negotiation yet — use the base offer to start',
      'freightNegotiation_baseOffer': 'Base offer', 'freightNegotiation_settled': 'Negotiation settled',
      'freightNegotiation_justNow': 'just now',
      'freightNegotiation_minAgo': '{minutes} min ago', 'freightNegotiation_hoursAgo': '{hours} h ago',
      'freightNegotiation_daysAgo': '{days} d ago',
      'driver_myDay': 'My Day', 'driver_assignedTransports': 'Assigned Transports',
      'driver_noTransports': 'No transports assigned', 'driver_vehicleInfo': 'Vehicle Info',
      'driver_expenses': 'Expenses', 'driver_documents': 'My Documents',
      'driver_tachograph_title': 'Tachograph',
      'driver_tachograph_note': 'Data comes from tachograph imports performed by dispatchers',
      'driver_copilotContextTrip': 'My current trip: {origin} → {destination}',
      'driver_copilotContextTransport': 'My current transport: {loadInfo}',
      'transport_status_planned': 'Planned', 'transport_status_loading': 'Loading',
      'transport_status_in_progress': 'In Progress', 'transport_status_in_transit': 'In Transit',
      'transport_status_delivered': 'Delivered', 'transport_status_cancelled': 'Cancelled',
      'transport_status_overdue': 'Overdue', 'transport_status_invoiced': 'Invoiced',
      'transport_status_paid': 'Paid', 'transport_status_maintenance': 'Maintenance',
      'transport_updateStatus': 'Update Status', 'transport_navigate': 'Navigate',
      'transport_route': 'Route', 'transport_details': 'Transport Details',
      'document_upload': 'Upload Document', 'document_capture': 'Take Photo',
      'document_selectGallery': 'Choose from Gallery', 'document_cmr': 'CMR', 'document_pod': 'POD',
      'document_invoice': 'Invoice', 'document_other': 'Other Document',
      'document_uploading': 'Uploading...', 'document_uploaded': 'Uploaded',
      'document_pending': 'Pending', 'document_failed': 'Upload Failed', 'document_noDocuments': 'No documents',
      'expense_new': 'New Expense', 'expense_type': 'Type', 'expense_fuel': 'Fuel',
      'expense_tolls': 'Tolls', 'expense_perDiem': 'Per Diem', 'expense_other': 'Other',
      'expense_amount': 'Amount', 'expense_date': 'Date', 'expense_receipt': 'Receipt',
      'expense_submit': 'Submit',
      'vehicle_assigned': 'Assigned Vehicle', 'vehicle_plate': 'Plate', 'vehicle_type': 'Type',
      'vehicle_documents': 'Vehicle Documents', 'vehicle_expiry': 'Expires',
      'message_noMessages': 'No messages', 'message_typeMessage': 'Type a message...',
      'message_send': 'Send', 'message_sending': 'Sending...', 'message_sent': 'Sent', 'message_you': 'You',
      'notification_newAssignment': 'New Transport Assigned', 'notification_scheduleChange': 'Schedule Changed',
      'notification_newMessage': 'New Message', 'notification_alert': 'Alert',
      'dispatcher_overview': 'Overview', 'dispatcher_activeJobs': 'Active Jobs',
      'dispatcher_activeDrivers': 'Active Drivers', 'dispatcher_openAlerts': 'Open Alerts',
      'dispatcher_liveFleet': 'Live Fleet', 'dispatcher_approve': 'Approve',
      'dispatcher_reject': 'Reject', 'dispatcher_reassign': 'Reassign',       'dispatcher_quickActions': 'Quick Actions',
      'dispatcher_jobDetails': 'Job Details',
      'dispatcher_markDelivered': 'Mark Delivered',
      'dispatcher_messageDriver': 'Message Driver',
      'dispatcher_reassignConfirm': 'Reassign to {driver}?',
      'dispatcher_reassignSuccess': 'Transport reassigned successfully',
      'dispatcher_markDeliveredSuccess': 'Job marked as delivered',
      'dispatcher_contactDriverPhone': 'Contact driver via phone',
      'dispatcher_noJobs': 'No jobs found',
      'dispatcher_all': 'All',
      'dispatcher_driver': 'Driver',
      'jobs_pending': 'Pending',
      'quickAction_approvePending': 'Approve pending jobs',
      'quickAction_approvePendingSubtitle': 'Jobs awaiting approval',
      'quickAction_alertCheck': 'Check alerts',
      'quickAction_alertCheckSubtitle': 'Open the alert inbox',
      'quickAction_scanDocument': 'Scan document',
      'quickAction_scanDocumentSubtitle': 'Capture + OCR',
      'notification_approve': 'Approve',
      'notification_snooze': 'Snooze',
      'notification_view': 'View',
      'general_created': 'Created',
      'alert_delay': 'Delay', 'alert_maintenance': 'Maintenance',
      'alert_documentExpiry': 'Document Expired', 'alert_compliance': 'Compliance',
      'alert_noAlerts': 'No alerts',
      'analytics_noData': 'No data for this period',
      'analytics_7d': '7d', 'analytics_30d': '30d', 'analytics_qtd': 'QTD',
      'analytics_ytd': 'YTD', 'analytics_custom': 'Custom',
      'analytics_customRange': 'Select date range',
      'analytics_revenueTab': 'Revenue', 'analytics_fleetUtilizationTab': 'Fleet Utilization',
      'analytics_driverPerformanceTab': 'Driver Performance', 'analytics_invoiceAgingTab': 'Invoice Aging',
      'analytics_export': 'Export', 'analytics_exportOffline': 'Export requires an internet connection',
      'analytics_exportStarted': 'Export started — you will be notified when ready',
      'analytics_exportError': 'Export failed. Please try again.',
      'analytics_groupByPeriod': 'Period', 'analytics_groupByClient': 'Client',
      'analytics_groupByRoute': 'Route', 'analytics_emptyHint': 'No data for this range',
      'analytics_status_active': 'Active', 'analytics_status_maintenance': 'In Service',
      'analytics_status_decommissioned': 'Decommissioned',
      'analytics_driverCol': 'Driver', 'analytics_tripsCol': 'Trips Completed',
      'analytics_otdCol': 'On-Time %', 'analytics_profitPerKmCol': 'Profit/km',
      'analytics_revenueCol': 'Revenue',
      'analytics_aging_current': 'Current', 'analytics_aging_31_60': '31–60 days',
      'analytics_aging_61_90': '61–90 days', 'analytics_aging_overdue': 'Over 90 days',
      'analytics_aging_total': 'Total Outstanding',
      'history_tripTitle': 'Trip History', 'history_routeTitle': 'Route History',
      'history_tripDetails': 'Trip details', 'history_routeDetails': 'Route details',
      'history_netProfit': 'Net profit',
      'history_statusFilter': 'Status', 'history_dateFrom': 'From', 'history_dateTo': 'To',
      'history_clientFilter': 'Client', 'history_export': 'Export',
      'history_exportOffline': 'Export requires an internet connection',
      'history_exportStarted': 'Export started — you will be notified when ready',
      'history_exportReady': 'Export ready', 'history_exportFailed': 'Export failed',
      'history_emptyTrips': 'No trips in this period',
      'history_emptyRoutes': 'No routes in this period',
      'history_distanceKm': '{distance} km', 'history_durationMin': '{duration} min',
      'history_loadingMore': 'Loading more...', 'history_noMore': 'No more data',
      'history_exportNoJobs': 'No export in progress', 'history_exportPolling': 'Generating export...',
      'globalSearch_title': 'Global Search', 'globalSearch_hint': 'Search trips, clients, drivers, trucks, documents...',
      'globalSearch_empty': 'No results found', 'globalSearch_minChars': 'Type at least 2 characters',
      'globalSearch_trips': 'Trips', 'globalSearch_clients': 'Clients',
      'globalSearch_drivers': 'Drivers', 'globalSearch_trucks': 'Trucks',
      'globalSearch_documents': 'Documents', 'globalSearch_more': '{count} more',
      'globalSearch_openSearch': 'Global search',
      'records_tripHistory': 'Trip History', 'records_routeHistory': 'Route History',
      'nav_invoicing': 'Invoicing', 'nav_maintenance': 'Maintenance',
      'invoicing_title': 'Invoice', 'invoicing_cached': 'Showing cached data',
      'invoicing_searchHint': 'Search invoices...',
      'invoicing_emptyTitle': 'No invoices yet',
      'invoicing_emptyHint': 'Tap + to create your first invoice',
      'invoicing_total': 'Total', 'invoicing_due': 'Due',
      'invoicing_statusAll': 'All', 'invoicing_statusDraft': 'Draft',
      'invoicing_statusFinalized': 'Finalized', 'invoicing_statusXml': 'XML Generated',
      'invoicing_statusPaid': 'Paid', 'invoicing_statusCancelled': 'Cancelled',
      'invoicing_stepperTitle': 'Status', 'invoicing_stepDraft': 'Draft',
      'invoicing_stepFinalized': 'Finalized', 'invoicing_stepXml': 'e-Factura XML',
      'invoicing_stepPaid': 'Paid',
      'invoicing_stepCancelled': 'Cancelled',
      'invoicing_client': 'Client', 'invoicing_clientHint': 'Select a client',
      'invoicing_clientSearch': 'Search clients...',
      'invoicing_clientRequired': 'Select a client before saving',
      'invoicing_trip': 'Trip', 'invoicing_tripShort': 'Trip',
      'invoicing_tripHint': 'Select a trip (optional)',
      'invoicing_tripSearch': 'Search trips...',
      'invoicing_noTrips': 'No trips found', 'invoicing_noClients': 'No clients found',
      'invoicing_lineItems': 'Line items', 'invoicing_addLine': 'Add line',
      'invoicing_noLines': 'No line items',
      'invoicing_noLinesHint': 'Add the first line item to build the invoice',
      'invoicing_unnamedLine': 'Unnamed line', 'invoicing_vatShort': 'VAT',
      'invoicing_subtotal': 'Subtotal', 'invoicing_vat': 'VAT',
      'invoicing_lineItem': 'Line item', 'invoicing_description': 'Description',
      'invoicing_descriptionRequired': 'Description is required',
      'invoicing_quantity': 'Quantity', 'invoicing_quantityRequired': 'Enter a valid quantity',
      'invoicing_unitPrice': 'Unit price', 'invoicing_priceRequired': 'Enter a price',
      'invoicing_discountPct': 'Discount %', 'invoicing_discountAmount': 'Discount amount',
      'invoicing_vatRate': 'VAT rate (%)', 'invoicing_invoiceNumber': 'Invoice no.',
      'invoicing_saveDraft': 'Save Draft', 'invoicing_finalize': 'Finalize',
      'invoicing_generateXml': 'Generate e-Factura XML',
      'invoicing_markPaid': 'Mark Paid', 'invoicing_noAction': 'No further action',
      'invoicing_cancel': 'Cancel invoice', 'invoicing_viewPdf': 'View PDF',
      'invoicing_pdfTitle': 'Invoice PDF',
      'invoicing_pdfError': 'Could not render the PDF on this device',
      'invoicing_savedDraft': 'Draft saved',
      'invoicing_savedOffline': 'Saved offline — will sync when back online',
      'invoicing_queuedOffline': 'Action queued — will sync when back online',
      'invoicing_requiresConnection': 'This action requires an internet connection',
      'invoicing_biometricReason': 'Authenticate to confirm this invoice action',
      'invoicing_biometricDenied': 'Authentication cancelled — action not completed',
      'invoicing_finalizedOk': 'Invoice finalized',
      'invoicing_xmlGeneratedOk': 'e-Factura XML generated',
      'invoicing_paidOk': 'Invoice marked as paid',
      'invoicing_cancelledOk': 'Invoice cancelled',
      'invoicing_cmrTitle': 'CMR document', 'invoicing_cmrSender': 'Sender',
      'invoicing_cmrSenderName': 'Sender name',
      'invoicing_cmrSenderNameRequired': 'Sender name is required',
      'invoicing_cmrSenderAddress': 'Sender address',
      'invoicing_cmrSenderAddressRequired': 'Sender address is required',
      'invoicing_cmrConsignee': 'Consignee',
      'invoicing_cmrFromTrip': 'Filled on the server from the trip data',
      'invoicing_cmrCarrier': 'Carrier', 'invoicing_cmrCarrierName': 'Carrier name',
      'invoicing_cmrCarrierLicense': 'Carrier license', 'invoicing_cmrGoods': 'Goods',
      'invoicing_cmrInstructions': 'Instructions', 'invoicing_cmrLanguage': 'Language',
      'invoicing_cmrCopies': 'Copies', 'invoicing_cmrIncludeStamps': 'Include stamps',
      'invoicing_cmrRemarks': 'Remarks', 'invoicing_cmrSignatures': 'Signatures',
      'invoicing_cmrClearSignature': 'Clear signature', 'invoicing_cmrSave': 'Save CMR',
      'invoicing_cmrSaved': 'CMR saved',
      'maintenance_costTrend': 'Cost trend', 'maintenance_schedules': 'Schedules',
      'maintenance_overdueOnly': 'Overdue only',
      'maintenance_emptyTitle': 'No maintenance schedules',
      'maintenance_emptyHint': 'Tap + to add a maintenance schedule',
      'maintenance_byType': 'By category', 'maintenance_overdue': 'OVERDUE',
      'maintenance_every': 'Every', 'maintenance_months': 'months',
      'maintenance_nextDue': 'Next due', 'maintenance_lastKm': 'Last done at',
      'maintenance_addSchedule': 'Add schedule', 'maintenance_truck': 'Truck',
      'maintenance_truckRequired': 'Select a truck',
      'maintenance_type': 'Maintenance type', 'maintenance_typeRequired': 'Enter a maintenance type',
      'maintenance_intervalKm': 'Interval (km)', 'maintenance_intervalMonths': 'Interval (months)',
      'maintenance_fixedExpiry': 'Fixed expiry date', 'maintenance_fixedExpiryHint': 'Optional — pick a date',
      'maintenance_scheduleAdded': 'Maintenance schedule added',
      'ocr_results': 'OCR Results',
      'ocr_processing': 'OCR processing in background. Results will appear later.',
      'ocr_confidence': '{percent}% confident',
      'general_cancel': 'Cancel', 'general_confirm': 'Confirm', 'general_save': 'Save',
      'general_delete': 'Delete', 'general_edit': 'Edit', 'general_retry': 'Retry',
      'general_loading': 'Loading...', 'general_error': 'An error occurred',
      'general_noInternet': 'No internet connection', 'general_offline': 'You are offline',
      'general_lastUpdated': 'Last updated', 'general_minAgo': '{count} min ago',
      'general_justNow': 'just now', 'general_hourAgo': 'an hour ago',
      'general_hoursAgo': '{count} hours ago', 'general_pendingSync': 'Pending sync',
      'general_comingSoon': 'Coming Soon',
      'general_comingSoonDescription': 'This feature will be available in a future update',
      'general_openDesktop': 'Open on desktop', 'general_yes': 'Yes', 'general_no': 'No',
      'settings_language': 'Language', 'settings_languageRo': 'Română', 'settings_languageEn': 'English',
      'settings_appearance': 'Appearance',
      'settings_theme': 'Theme', 'settings_themeSystem': 'System', 'settings_themeLight': 'Light',
      'settings_themeDark': 'Dark',       'settings_appVersion': 'App Version',
      'nav_teamsManagement': 'Team Management', 'nav_tachograph': 'Tachograph',
      'settings_saved': 'Settings saved',
      'settings_saveFailed': 'Could not save settings',
      'settings_saving': 'Saving...', 'settings_save': 'Save',
      'settings_companyProfile': 'Company Profile',
      'settings_legalName': 'Legal name', 'settings_vatNumber': 'VAT number',
      'settings_address': 'Address', 'settings_invoiceFooter': 'Invoice footer',
      'settings_smtp': 'SMTP Configuration', 'settings_smtpServer': 'SMTP server',
      'settings_smtpPort': 'SMTP port', 'settings_smtpUser': 'SMTP user',
      'settings_smtpPassword': 'SMTP password',
      'settings_configuredPlaceholder': '•••• configured',
      'settings_sendTestEmail': 'Send test email',
      'settings_testEmailSent': 'Test email sent',
      'settings_testEmailFailed': 'Test email failed',
      'settings_tracking': 'Fleet Tracking Provider',
      'settings_trackingApiKey': 'Tracking API key',
      'settings_trackingNone': 'None',
      'settings_maintenanceThresholds': 'Maintenance Thresholds',
      'settings_maintenanceAlertDays': 'Maintenance alert (days)',
      'settings_tachoWarningDays': 'Tacho warning (days)',
      'settings_tachoCriticalDays': 'Tacho critical (days)',
      'settings_notifications': 'Notification Preferences',
      'settings_notifCritical': 'Critical', 'settings_notifWarning': 'Warnings',
      'settings_notifInfo': 'Informational', 'settings_quietHours': 'Quiet hours',
      'settings_dataUsage': 'Data Usage',
      'settings_wifiOnlyLargeSyncs': 'Wi-Fi only for large syncs',
      'settings_wifiOnlyLargeSyncsHint': 'Block large syncs and uploads on cellular data',
      'settings_biometricLock': 'Biometric Lock',
      'settings_biometricUnlock': 'Biometric unlock',
      'settings_biometricUnlockHint': 'Show the biometric button on the sign-in screen',
      'settings_requireFinancial': 'Require for financial actions',
      'settings_requireFinancialHint': 'Ask for biometric confirmation before sensitive financial actions',
      'wifi_only_message': 'Wi-Fi only is enabled — connect to a Wi-Fi network for this action',
      'team_inviteTitle': 'Invite a member', 'team_inviteEmail': 'Email',
      'team_inviteEmailRequired': 'Email is required',
      'team_inviteEmailInvalid': 'Enter a valid email address',
      'team_inviteRole': 'Role', 'team_inviteBtn': 'Invite', 'team_inviting': 'Sending...',
      'team_memberDetails': 'Member details',
      'team_inviteSent': 'Invitation sent',
      'team_inviteFailed': 'Invitation failed',
      'team_requiresConnection': 'This action requires an internet connection',
      'team_notPermitted': 'You do not have permission to manage the team',
      'team_deactivateTitle': 'Deactivate user',
      'team_deactivateMessage': 'This will immediately revoke {name}\'s mobile sessions and log them out of all devices',
      'team_deactivate': 'Deactivate',
      'team_deactivated': 'User deactivated',
      'team_actionFailed': 'Action failed',
      'team_roleUpdated': 'Role updated',
      'team_emptyTitle': 'No members yet',
      'team_emptyHint': 'Use + to invite your first member',
      'team_cached': 'Showing cached data',
      'team_active': 'Active', 'team_inactive': 'Inactive',
      'team_moreActions': 'More actions',
      'tacho_selectDriverTitle': 'Choose a driver',
      'tacho_selectDriver': 'Select a driver',
      'tacho_driverSearch': 'Search drivers...',
      'tacho_noDrivers': 'No drivers found',
      'tacho_noDriverSelected': 'Select a driver first',
      'tacho_importFile': 'Import .ddd file',
      'tacho_importing': 'Importing...',
      'tacho_processing': 'Processing card...',
      'tacho_uploadFailed': 'Import failed',
      'tacho_requiresConnection': 'Importing requires an internet connection',
      'tacho_wifiOnly': 'Wi-Fi only is enabled — connect to Wi-Fi to import',
      'tacho_imported': 'Card imported',
      'tacho_empty': 'Nothing to show yet',
      'tacho_emptyHint': 'Import a .ddd or .esm file from the driver\'s tachograph',
      'tacho_complianceTitle': 'Compliance summary',
      'tacho_weeklyDriving': 'Weekly driving',
      'tacho_overLimit': 'Over the weekly driving limit',
      'tacho_days': 'Days', 'tacho_violations': 'Warnings',
      'tacho_noViolations': 'No violations detected',
      'ai_title': 'AI Co-Pilot', 'ai_emptyStateMessage': 'Ask me anything about your fleet',
      'ai_emptyStatePrompt': 'Try: "Show my available trucks"',
      'ai_clarifyPlaceholder': 'Type your answer...', 'ai_newConversation': 'New conversation',
      'ai_placeholder': 'Type a command or question...',
      'ai_confirmTitle': 'Confirm Action',
      'ai_confirmMessage': 'Operion AI suggests the following action:',
      'copilot_level3_title': 'Level 3 — Type confirmation to proceed',
      'copilot_level3_warning': 'This action is IRREVERSIBLE. Type the confirmation phrase to continue.',
      'copilot_level3_hint': 'Type the confirmation phrase...',
      'copilot_level3_phrase': 'Type: "{phrase}"',
      'copilot_maintenanceCapture': 'Record maintenance',
      'copilot_maintenanceEmpty': 'Maintenance details from your request',
      'copilot_maintenanceSelectTruck': 'Select truck',
      'copilot_maintenanceConfirm': 'Pre-fill & confirm',
      'copilot_maintenanceSaved': 'Maintenance record saved',
      'profile_personalInfo': 'Personal Information',
      'profile_driverInfo': 'Driver Information',
      'profile_quickLinks': 'Quick Links',
      'profile_licenseNumber': 'License Number',
      'profile_licenseCategory': 'License Category',
      'profile_licenseExpiry': 'License Expiry',
      'profile_phone': 'Phone',
      'profile_displayName': 'Display Name',
      'profile_noDriverInfo': 'No driver information available',
      'profile_documentLicense': 'Driver License',
      'profile_documentPassport': 'Passport',
      'profile_documentAdr': 'ADR Certificate',
      'profile_selectCamera': 'Camera',
      'profile_selectGallery': 'Gallery',
      'profile_noDocuments': 'No documents uploaded',
      'profile_uploadSuccess': 'Document uploaded successfully',
      'profile_uploadError': 'Upload failed',
      'driverOverview_emptyState': 'No active trip',
      'driverOverview_emptyStateSubtitle': 'You have no transport assigned at this time.',
      'driverOverview_etaUnavailable': 'ETA unavailable',
      'transport_statusUpdated': 'Status updated',
      'transport_eta': 'ETA',
      'transport_elapsedTime': 'Elapsed Time',
      'routeShare_noData': 'No route data',
      'routeShare_noDataSubtitle': 'Route information is not yet available for this transport.',
      'routeShare_distance': 'Distance',
      'routeShare_estimatedTime': 'Est. Time',
      'routeShare_offRoute': 'You appear to be off route',
      'routeShare_backgroundBanner': 'Navigation will pause when app is backgrounded',
      'routeShare_permissionDenied': 'Location access is denied. Position updates are unavailable.',
      'routeShare_fgNotificationTitle': '{instruction}',
      'routeShare_fgNotificationBody': '{distance} · {eta} remaining',
      'routeShare_fgChannelName': 'Operion Navigation',
      'transport_action_startLoading': 'Start Loading',
      'transport_action_depart': 'Depart',
      'transport_action_markDelivered': 'Mark Delivered',
      'transport_action_reportDelay': 'Report Delay',
      'transport_action_noActions': 'No actions available',
      'profitCalculator_title': 'Profit Calculator',
      'profitCalculator_price': 'Price',
      'profitCalculator_fuelCost': 'Fuel Cost',
      'profitCalculator_tollCost': 'Toll Cost',
      'profitCalculator_driverCost': 'Driver Cost',
      'profitCalculator_extraCosts': 'Extra Costs',
      'profitCalculator_calculate': 'Calculate',
      'profitCalculator_totalCosts': 'Total Costs',
      'profitCalculator_profit': 'Profit',
      'profitCalculator_profitMargin': 'Profit Margin',
      'profitCalculator_currencySymbol': '\$',
      'teams_filterAll': 'All',
      'teams_filterAvailable': 'Available',
      'teams_filterDriving': 'Driving',
      'teams_filterOff': 'Off',
      'teams_placeholder': 'Driver list will appear here when connected to the server.',
      'teams_licenseNumber': 'License Number',
      'teams_licenseCategory': 'License Category',
      'teams_licenseExpiry': 'License Expiry',
      'teams_medicalExpiry': 'Medical Expiry',
      'teams_assignedVehicle': 'Assigned Vehicle',
      'teams_assignedTransport': 'Assigned Transport',
      'teams_licenseValid': 'Valid',
      'teams_licenseExpiringSoon': 'Expiring soon',
      'teams_licenseExpired': 'Expired',
      'teams_notAssigned': 'Not assigned',
      'teams_detailLoadError': 'Could not load driver details.',

      // ── Document Center ──
      'documentCenter_title': 'Document Center',
      'documentCenter_documents': 'Documents',
      'documentCenter_automation': 'Automation',
      'documentCenter_ocrTitle': 'OCR Document Capture',
      'documentCenter_ocrDescription': 'Capture a document photo to automatically extract fields.',
      'documentCenter_capturePhoto': 'Capture Photo',
      'documentCenter_uploadConfirmed': 'Upload confirmed, processing...',
      'documentCenter_uploadInProgress': 'Uploading...',
      'documentCenter_uploadError': 'Upload failed. Please try again.',
      'documentCenter_processingHint': 'The document is processed in the cloud. Results will appear under Local Download.',
      'documentCenter_captureAnother': 'Capture another document',
      'documentCenter_documentsEmpty': 'All company documents will appear here.',
      'documentCenter_documentsError': 'Could not load the document list.',

      // ── Local Download ──
      'localDownload_title': 'Local Download',
      'localDownload_selectCategory': 'Select Category',
      'localDownload_download': 'Download',
      'localDownload_categoryDocuments': 'Documents',
      'localDownload_categoryInvoices': 'Invoices',
      'localDownload_categoryReceipts': 'Receipts',
      'localDownload_categoryOcrResults': 'OCR Results',
      'localDownload_categoryTripHistory': 'Trip History',
      'localDownload_dateFrom': 'From',
      'localDownload_dateTo': 'To',
      'localDownload_progress': 'Downloading...',
      'localDownload_complete': 'Download complete',
      'localDownload_downloadAll': 'Download all',
      'localDownload_manifestEmpty': 'No files to download',
      'localDownload_manifestError': 'Could not load the file list.',
      'nav_records': 'Records',
      'records_searchHint': 'Search records...',
      'records_emptyTitle': 'No records available',
      'records_emptyHint': 'No matching records found',
      'records_fleet': 'Fleet',
      'records_drivers': 'Drivers',
      'records_clients': 'Clients',
      'fleet_cached': 'Showing cached data',
      'fleet_searchHint': 'Search by plate, brand or model...',
      'fleet_emptyTitle': 'No trucks yet',
      'fleet_emptyHint': 'Tap + to add your first truck',
      'fleet_statusActive': 'Active',
      'fleet_statusMaintenance': 'In Service',
      'fleet_statusDecommissioned': 'Inactive',
      'fleet_edit': 'Edit',
      'fleet_decommission': 'Decommission',
      'fleet_decommissionConfirm': 'Decommissioning is irreversible. Continue?',
      'fleet_overview': 'Overview',
      'fleet_maintenance': 'Maintenance',
      'fleet_documents': 'Documents',
      'fleet_assignments': 'Assignments',
      'fleet_vin': 'VIN',
      'fleet_year': 'Year',
      'fleet_health': 'Health',
      'fleet_currentDriver': 'Current driver',
      'fleet_noMaintenance': 'No maintenance records',
      'fleet_recordWorkHint': 'Use the + button to record maintenance work',
      'fleet_documentsPlaceholder': 'Document Center integration arrives in a later phase',
      'fleet_noDocuments': 'No documents',
      'fleet_assignmentsNote': 'Assignments are managed from the dispatch flow',
      'fleet_editTitle': 'Truck details',
      'fleet_plate': 'Plate',
      'fleet_plateRequired': 'Plate is required',
      'fleet_brand': 'Brand',
      'fleet_brandRequired': 'Brand is required',
      'fleet_model': 'Model',
      'fleet_modelRequired': 'Model is required',
      'fleet_recordWork': 'Record work',
      'fleet_date': 'Date',
      'fleet_category': 'Category',
      'fleet_cost': 'Cost',
      'fleet_costRequired': 'Enter a valid cost',
      'fleet_vendor': 'Vendor',
      'fleet_notes': 'Notes',
      'fleet_categoryOil': 'Oil change',
      'fleet_categoryTires': 'Tires',
      'fleet_categoryBrakes': 'Brakes',
      'fleet_categoryEngine': 'Engine',
      'fleet_categoryBodywork': 'Bodywork',
      'fleet_categoryInspection': 'Inspection',
      'fleet_categoryOther': 'Other',
      'teams_filterExpiring': 'Expiring',
      'teams_expired': 'EXPIRED',
      'teams_daysShort': 'd',
      'teams_editDriver': 'Edit driver',
      'teams_overview': 'Overview',
      'teams_compliance': 'Compliance',
      'teams_tacho': 'Tacho',
      'teams_assignments': 'Assignments',
      'teams_renew': 'Renew',
      'teams_adrExpiry': 'ADR Certificate Expiry',
      'teams_expiryWindow': 'Expiry window:',
      'teams_weeklyDriving': 'Weekly driving',
      'teams_weeklyLimit': 'Weekly limit:',
      'teams_weeklyOverLimit': 'Over the weekly driving limit',
      'teams_tachoEmpty': 'No tacho data available',
      'teams_assignmentsNote': 'Assignments are managed from the dispatch flow',
      'teams_editTitle': 'Driver details',
      'teams_phone': 'Phone',
      'teams_email': 'Email',
      'tacho_driving': 'Driving',
      'tacho_working': 'Working',
      'tacho_rest': 'Rest',
      'tacho_availability': 'Available',
      'nav_clients': 'Clients',
      'clients_cached': 'Showing cached data',
      'clients_searchHint': 'Search clients...',
      'clients_emptyTitle': 'No clients yet',
      'clients_emptyHint': 'Tap + to add your first client',
      'clients_paymentTerms': 'Payment terms',
      'clients_daysShort': 'days',
      'clients_active': 'Active',
      'clients_inactive': 'Inactive',
      'clients_editTitle': 'Client details',
      'clients_name': 'Name',
      'clients_nameRequired': 'Name is required',
      'clients_vatNumber': 'VAT number',
      'clients_address': 'Address',
      'clients_details': 'Details',
      'clients_contacts': 'Contacts',
      'clients_invoices': 'Invoices',
      'clients_trips': 'Trips',
      'clients_rating': 'Rating',
      'clients_noPermission': 'You don\'t have permission to manage contacts',
      'clients_addContact': 'Add Contact',
      'clients_noContacts': 'No contacts yet',
      'clients_addContactHint': 'Add the first contact for this client',
      'clients_recentInvoices': 'Recent invoices:',
      'clients_recentTrips': 'Recent trips:',
      'clients_invoicesPlaceholder': 'Invoices arrive in a later phase',
      'clients_invoicesPlaceholderHint': 'Invoice history will be wired in Phase 3',
      'clients_tripsPlaceholder': 'Trips arrive in a later phase',
      'clients_tripsPlaceholderHint': 'Trip history will be wired in Phase 2',
      'clients_noInvoices': 'No invoices yet',
      'clients_noInvoicesHint': 'Invoices for this client will appear here.',
      'clients_noTrips': 'No trips yet',
      'clients_noTripsHint': 'Trips for this client will appear here.',
      'clients_editContactTitle': 'Contact details',
      'clients_contactName': 'Contact name',
      'clients_contactNameRequired': 'Contact name is required',
      'clients_contactRole': 'Role',
      'clients_contactPhone': 'Phone',
      'clients_contactEmail': 'Email',
      'clients_merge': 'Merge clients',
      'clients_mergeTarget': 'Target client',
      'clients_mergeSources': 'Clients to merge',
      'clients_mergeTypeConfirm': 'Type the target\'s exact name to confirm',
      'clients_mergeOffline': 'Merging requires an internet connection',
      'clients_mergeBtn': 'Merge',
      'clients_mergeSummary': 'Estimated merged totals',
      'clients_tripsShort': 'Trips:',
      'clients_invoicesShort': 'Invoices:',
      'clients_contactsShort': 'Contacts:',
      'localDownload_saved': 'Saved to device',
      // ── §2 Feature-parity ────────────────────────────────────────
      'dispatcher_revenueTrend': 'Revenue trend',
      'dispatcher_activityFeed': 'Recent activity',
      'dispatcher_activityEmpty': 'No recent activity',
      'routePlanner_profile': 'Routing profile',
      'routePlanner_profileTruck': 'Truck',
      'routePlanner_profileCar': 'Car',
      'routePlanner_profilePedestrian': 'Pedestrian',
      'routePlanner_avoidCountries': 'Countries to avoid',
      'routePlanner_avoidCountriesHint': 'Select the countries the route should avoid',
      'routePlanner_selectCountries': 'Select countries',
      'documentCenter_searchHint': 'Search documents...',
      'documentCenter_allCategories': 'All',
      'documentCenter_versions': 'Versions',
      'documentCenter_noVersions': 'No versions',
      'documentCenter_versionNumber': 'Version',
      'documentCenter_uploadedBy': 'Uploaded by',
      'documentCenter_previewUnavailable': 'Preview is not available for this document type',
      'jobs_viewList': 'List',
      'jobs_viewKanban': 'Kanban',
      'jobs_viewTimeline': 'Timeline',
      'jobs_kanbanHint': 'Long-press and drag cards between columns',
      'jobs_kanbanEmpty': 'No jobs',
      'jobs_moved': 'Job moved',
      'jobs_undo': 'Undo',
      'jobs_moveFailed': 'Move failed. The job was restored.',
      'jobs_timelineNoDates': 'Jobs without start/end dates are shown as markers',
      'jobs_timelineUnassigned': 'Unassigned',
      'freightExchange_moreFilters': 'More filters',
      'freightExchange_advancedSearch': 'Advanced search',
      'freightExchange_pickupFrom': 'Pickup from',
      'freightExchange_pickupTo': 'Pickup to',
      'freightExchange_weightMin': 'Weight min (kg)',
      'freightExchange_weightMax': 'Weight max (kg)',
      'freightExchange_trailerType': 'Trailer type',
      'freightExchange_priceMin': 'Price min',
      'freightExchange_priceMax': 'Price max',
      'freightExchange_savedSearches': 'Saved searches',
      'freightExchange_saveCurrentSearch': 'Save current search',
      'freightExchange_savedSearchLabel': 'Search name',
      'freightExchange_savedSearchLabelHint': 'e.g. Berlin → Bucharest',
      'freightExchange_searchSaved': 'Search saved',
      'freightExchange_saveSearchError': 'Could not save search',
      'freightExchange_noSavedSearches': 'No saved searches yet',
      'freightExchange_deleteSearch': 'Delete search',
      'freightExchange_deleteSearchConfirm': 'Delete this saved search?',
      'freightExchange_runSearch': 'Run',
      'freightExchange_evaluate': 'Evaluate',
      'freightExchange_evaluation': 'Load evaluation',
      'freightExchange_evaluationError': 'Evaluation failed',
      'freightExchange_estimatedRevenue': 'Estimated revenue',
      'freightExchange_expectedProfit': 'Expected profit',
      'freightExchange_profitMargin': 'Margin',
      'freightExchange_fuelCost': 'Fuel',
      'freightExchange_tollCost': 'Tolls',
      'freightExchange_driverSalary': 'Driver',
      'freightExchange_deadheadKm': 'Deadhead',
      'freightExchange_durationHours': 'Duration',
      'freightExchange_riskScore': 'Risk',
      'freightExchange_vehicleCompatibility': 'Vehicle compatibility',
      'freightExchange_vehicleCompatible': 'Vehicle compatible',
      'freightExchange_vehicleIncompatible': 'Vehicle not compatible',
      'freightExchange_riskLow': 'Low',
      'freightExchange_riskMedium': 'Medium',
      'freightExchange_riskHigh': 'High',
      'general_done': 'Done',
    },
  };
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations.supportedLocales.any((l) => l.languageCode == locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async => AppLocalizations(locale);

  @override
  bool shouldReload(covariant _AppLocalizationsDelegate old) => false;
}
