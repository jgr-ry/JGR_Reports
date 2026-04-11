--[[
    JGR_Reports — English (en)
    All user-facing strings. Use JGRReportsT('key') in Lua or pass this table to NUI.
]]

JGRReportsLocales = JGRReportsLocales or {}
JGRReportsLocales['en'] = {
    -- Commands (server)
    cmd_report_desc = 'Open the player report system',
    cmd_reportes_desc = 'Open the staff report panel',

    -- Server / shared notifies
    notify_call_joined = 'Connected to support call.',
    notify_call_left = 'Call ended.',
    notify_report_sent = 'Report submitted successfully.',
    notify_report_fail = 'Could not submit the report.',
    notify_report_taken = 'A staff member is handling your report. Status updated.',
    notify_report_closed = 'The report has been closed.',
    notify_report_closed_by_you = 'You closed the report.',
    notify_report_closed_by_player_staff = 'The player %s closed the report.',
    notify_report_closed_inactivity = 'Your report was closed automatically due to inactivity (long disconnect).',
    notify_report_closed_staff_ok = 'Report closed successfully.',
    notify_report_inactivity_staff = 'Report #%d closed due to player inactivity.',
    notify_new_report = 'New report from %s [ID:%s]',
    notify_staff_attending = 'Staff %s is handling your report',
    notify_no_permission = 'You do not have permission.',
    notify_call_incoming = 'Incoming support call...',
    notify_call_declined = 'The player declined the call.',
    notify_player_offline = 'The player is not online.',
    notify_invalid_report = 'Invalid report.',

    -- NUI — static
    ui_page_title = 'JGR Reports',
    ui_support_title = 'Live support',
    ui_incident_title_label = 'Incident title',
    ui_incident_title_ph = 'e.g. Visual bug in inventory',
    ui_desc_label = 'Detailed description',
    ui_desc_ph = 'Explain your issue as clearly as possible...',
    ui_priority_label = 'Priority',
    ui_prio_baja = 'Low',
    ui_prio_media = 'Medium',
    ui_prio_alta = 'High',
    ui_send_report = 'Submit report',
    ui_admin_panel = 'Administration panel',
    ui_search_ph = 'Search by name, ID or title...',
    ui_tab_active = 'Active',
    ui_tab_history = 'History',
    ui_chat_input_ph = 'Type a message...',
    ui_call_player = 'Call player',
    ui_close_report = 'Close report',
    ui_call_subtitle = 'Administrative support',
    ui_call_ringing = 'Calling...',
    ui_decline = 'Decline',
    ui_accept = 'Accept',
    ui_hangup = 'Hang up',

    -- NUI — dynamic
    ui_staff_loading = 'Loading staff...',
    ui_staff_none = 'No staff online right now',
    ui_staff_count = '%d staff online',
    ui_loading = 'Loading...',
    ui_no_active = 'No active reports found.',
    ui_no_history = 'No reports in history.',
    ui_btn_view_chat = 'Open chat',
    ui_btn_take = 'Take',
    ui_player_default = 'Player',
    ui_online = 'Online',
    ui_offline = 'Offline',
    ui_attended_by = 'Handled by:',
    ui_review = 'Review',
    ui_report_title_fmt = 'Report #%s',
    ui_chat_summary_label = 'Problem description',
    ui_no_description = 'No description',

    -- Report status (display; DB keeps Spanish values)
    status_Abierto = 'Open',
    status_En_progreso = 'In progress',
    status_Cerrado = 'Closed',

    -- History close reasons
    ui_history_closed_staff = 'Closed by staff:',
    ui_history_closed_user = 'Closed by the player:',
    ui_history_closed_user_fallback = 'Closed by the player (reporting user).',
    ui_history_closed_inactivity = 'Closed automatically due to inactivity (player offline more than %s min)',
    ui_history_legacy = 'Closed (legacy record, no details)',

    -- Time ago
    time_now = 'Just now',
    time_min = '%d min',
    time_h = '%d h',
    time_d = '%d d',
    time_months = '%d months',
    time_years = '%d years',

    ui_unknown = 'Unknown',
}
