const post = (endpoint, data = {}) => fetch(`https://${GetParentResourceName()}/${endpoint}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data)
});

function escapeHtml(text) {
    if (text == null || text === '') return '';
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

let L = {};
let localeLang = 'es';

function applyLocale(pack, lang) {
    if (pack && typeof pack === 'object') L = pack;
    if (lang) localeLang = lang;
    document.documentElement.lang = localeLang === 'en' ? 'en' : 'es';
    const pt = document.getElementById('page-title');
    if (pt && L.ui_page_title) pt.textContent = L.ui_page_title;
    document.querySelectorAll('[data-i18n]').forEach(el => {
        const k = el.getAttribute('data-i18n');
        if (k && L[k] != null && L[k] !== '') el.textContent = L[k];
    });
    document.querySelectorAll('[data-i18n-placeholder]').forEach(el => {
        const k = el.getAttribute('data-i18n-placeholder');
        if (k && L[k] != null) el.setAttribute('placeholder', L[k]);
    });
}

function T(key) {
    return (L[key] != null && L[key] !== '') ? L[key] : key;
}

function Tfmt(key, ...args) {
    let s = T(key);
    args.forEach(a => {
        s = s.replace(/%[sd]/, String(a));
    });
    return s;
}

const STATUS_MAP = {
    'Abierto': 'status_Abierto',
    'En progreso': 'status_En_progreso',
    'Cerrado': 'status_Cerrado',
};

function trStatus(dbStatus) {
    const kk = STATUS_MAP[dbStatus];
    return (kk && L[kk]) ? L[kk] : dbStatus;
}

function trPriority(p) {
    const m = { 'Baja': 'ui_prio_baja', 'Media': 'ui_prio_media', 'Alta': 'ui_prio_alta' };
    const kk = m[p];
    return kk ? T(kk) : (p || '');
}

let currentReport = null;
let isAdminContext = false;
let currentCallTarget = null;
let incomingCallReportId = null;
let autoCloseOfflineMinutes = 10;

const app = document.getElementById('app');
const views = document.querySelectorAll('.view');
const createReportView = document.getElementById('create-report-view');
const adminPanelView = document.getElementById('admin-panel-view');
const chatView = document.getElementById('chat-view');

const incomingCallModal = document.getElementById('incoming-call-modal');
const activeCallModal = document.getElementById('active-call-modal');

// Close and Back logic
document.querySelectorAll('.close-btn').forEach(btn => {
    btn.addEventListener('click', (e) => {
        if (e.currentTarget.classList.contains('back-btn')) {
            // Si es admin y pulsó volver, lo mandamos al admin panel en lugar de cerrar toda la UI
            if (isAdminContext) {
                switchView(adminPanelView);
                loadAdminReports();
                return;
            }
        }
        post('closeUI');
    });
});

document.onkeyup = function (data) {
    if (data.which == 27) { // ESC
        post('closeUI');
    }
};

// SONIDOS UI NATIVOS
document.querySelectorAll('.ui-sound').forEach(el => {
    el.addEventListener('click', (e) => {
        const soundType = e.currentTarget.getAttribute('data-sound') || 'click';
        post('playSound', { sound: soundType });
    });
});

function switchView(viewElement) {
    views.forEach(v => v.classList.add('hidden'));
    viewElement.classList.remove('hidden');
    app.style.display = 'flex';
}

function checkAndCloseEmptyUI() {
    let hasActiveView = false;
    views.forEach(v => {
        if (!v.classList.contains('hidden')) hasActiveView = true;
    });
    // Si no hay ninguna vista principal abierta (solo estaba el modal de llamada), cerramos la interfaz
    if (!hasActiveView) {
        post('closeUI');
    }
}

// ==========================================
// STAFF ACTIVO (Vista crear reporte)
// ==========================================
function renderActiveStaff(staffList) {
    const label = document.getElementById('staff-online-label');
    const list = document.getElementById('staff-online-list');
    list.innerHTML = '';

    if (!staffList || staffList.length === 0) {
        label.textContent = T('ui_staff_none');
        label.style.color = '#ff6b6b';
        document.querySelector('.staff-online-dot').style.background = '#ff6b6b';
    } else {
        label.textContent = Tfmt('ui_staff_count', staffList.length);
        label.style.color = '#30d158';
        document.querySelector('.staff-online-dot').style.background = '#30d158';
        staffList.forEach(staff => {
            const badge = document.createElement('div');
            badge.className = 'staff-badge';
            badge.innerHTML = `
                <i class="fa-solid fa-shield-halved"></i>
                <span class="staff-badge-name">${staff.name}</span>
                <span class="staff-badge-steam">${staff.steamName}</span>
            `;
            list.appendChild(badge);
        });
    }
}

window.addEventListener('message', (event) => {
    const data = event.data;

    switch (data.action) {
        case "close":
            app.style.display = 'none';
            break;

        case "open_create":
            if (data.strings) applyLocale(data.strings, data.localeLang);
            document.getElementById('create-report-form').reset();
            document.querySelectorAll('.btn-priority').forEach(b => b.classList.remove('active'));
            document.querySelector('.btn-priority.baja').classList.add('active');
            selectedPriority = 'Baja';

            renderActiveStaff(data.staffList || []);

            switchView(createReportView);
            break;

        case "open_admin":
            if (data.strings) applyLocale(data.strings, data.localeLang);
            autoCloseOfflineMinutes = typeof data.autoCloseMinutes === 'number' ? data.autoCloseMinutes : 10;
            loadAdminReports();
            switchView(adminPanelView);
            break;

        case "refresh_admin_lists":
            if (adminPanelView.classList.contains('hidden')) break;
            {
                const activeSeg = document.querySelector('.segment-btn.active');
                const tab = activeSeg ? activeSeg.getAttribute('data-tab') : null;
                if (tab === 'active-reports') loadAdminReports();
                else if (tab === 'history-reports') loadAdminHistory();
            }
            break;

        case "open_chat":
            if (data.strings) applyLocale(data.strings, data.localeLang);
            currentReport = data.report;
            isAdminContext = data.isAdmin;
            setupChatView(data.messages);
            switchView(chatView);
            break;

        case "receive_message":
            post('playSound', { sound: 'message' });
            appendMessage(data.sender, data.message, data.isAdmin, new Date());
            break;

        case "report_closed_forcefully":
            if (currentReport) {
                currentReport.status = "Cerrado";
                setupChatView([]); // refresh states
            }
            break;

        case "incoming_call":
            if (data.strings) applyLocale(data.strings, data.localeLang);
            app.style.display = 'flex';
            incomingCallReportId = data.reportId;
            incomingCallModal.classList.remove('hidden');
            break;

        case "call_started":
            app.style.display = 'flex'; // Por si acaso
            incomingCallModal.classList.add('hidden');
            activeCallModal.classList.remove('hidden');
            startCallTimer();
            break;

        case "call_declined":
            incomingCallModal.classList.add('hidden');
            checkAndCloseEmptyUI();
            break;

        case "call_ended":
            incomingCallModal.classList.add('hidden');
            activeCallModal.classList.add('hidden');
            stopCallTimer();
            checkAndCloseEmptyUI();
            break;
    }
});

// ==========================================
// UTILIDADES (Time Ago)
// ==========================================
function timeAgo(date) {
    if (!date) return T('time_now');
    const seconds = Math.floor((new Date() - new Date(date)) / 1000);

    let interval = seconds / 31536000;
    if (interval > 1) return Tfmt('time_years', Math.floor(interval));
    interval = seconds / 2592000;
    if (interval > 1) return Tfmt('time_months', Math.floor(interval));
    interval = seconds / 86400;
    if (interval > 1) return Tfmt('time_d', Math.floor(interval));
    interval = seconds / 3600;
    if (interval > 1) return Tfmt('time_h', Math.floor(interval));
    interval = seconds / 60;
    if (interval > 1) return Tfmt('time_min', Math.floor(interval));
    return T('time_now');
}

// ==========================================
// HELPER: Parsear el sender string del servidor
// Formato: "[Staff] Nombre (SteamName) [ID:X]" o "Nombre (SteamName) [ID:X]"
// ==========================================
function parseSender(senderStr, isAdmin) {
    if (!senderStr) return { label: T('ui_unknown'), id: '', steam: '', isStaff: false };

    let isStaff = senderStr.startsWith('[Staff]');
    let clean = senderStr.replace('[Staff] ', '').replace('[Staff]', '');

    // Extraer ID: [ID:X]
    const idMatch = clean.match(/\[ID:(\d+)\]/);
    const id = idMatch ? idMatch[1] : '';
    clean = clean.replace(/\s*\[ID:\d+\]/, '');

    // Extraer steam (lo que hay entre los últimos paréntesis)
    const steamMatch = clean.match(/\((.+?)\)\s*$/);
    const steam = steamMatch ? steamMatch[1] : '';
    clean = clean.replace(/\s*\(.+?\)\s*$/, '').trim();

    return { label: clean, id, steam, isStaff };
}

// ==========================================
// FORMULARIOS Y PRIORIDADES
// ==========================================
let selectedPriority = 'Baja';

document.querySelectorAll('.btn-priority').forEach(btn => {
    btn.addEventListener('click', (e) => {
        const el = e.target.closest('.btn-priority');
        if (!el) return;
        document.querySelectorAll('.btn-priority').forEach(b => b.classList.remove('active'));
        el.classList.add('active');
        selectedPriority = el.getAttribute('data-prio');
    });
});

document.getElementById('create-report-form').addEventListener('submit', (e) => {
    e.preventDefault();
    const title = document.getElementById('report-title').value;
    const desc = document.getElementById('report-desc').value;

    post('createReport', { title, description: desc, priority: selectedPriority }).then(r => r.json()).then(res => {
        if (res.success) {
            post('closeUI');
        }
    });
});

// ==========================================
// CHAT & DROPDOWN MENU
// ==========================================
const chatOptionsBtn = document.getElementById('chat-options-btn');
const chatOptionsMenu = document.getElementById('chat-options-menu');

chatOptionsBtn.addEventListener('click', () => {
    chatOptionsMenu.classList.toggle('hidden');
});

// Cerrar menu si clickean afuera
document.addEventListener('click', (e) => {
    if (!chatOptionsBtn.contains(e.target) && !chatOptionsMenu.contains(e.target)) {
        chatOptionsMenu.classList.add('hidden');
    }
});

function priorityBadgeClass(priority) {
    const p = (priority || 'Baja').toLowerCase();
    if (p === 'media') return 'prio-media';
    if (p === 'alta') return 'prio-alta';
    return 'prio-baja';
}

function setupChatView(messagesData) {
    document.getElementById('chat-title').innerText = Tfmt('ui_report_title_fmt', currentReport.id);

    const statusDot = document.getElementById('chat-status');
    statusDot.innerText = trStatus(currentReport.status);
    statusDot.className = `status-dot ${currentReport.status.replace(' ', '.')}`;

    const adminSummaryEl = document.getElementById('chat-admin-summary');

    if (isAdminContext && adminSummaryEl) {
        adminSummaryEl.classList.remove('hidden');

        const prioLabel = escapeHtml(trPriority(currentReport.priority || 'Baja'));
        const prioClass = priorityBadgeClass(currentReport.priority);
        const rawDesc = (currentReport.description && String(currentReport.description).trim())
            ? currentReport.description
            : T('ui_no_description');
        const desc = escapeHtml(rawDesc);

        let meta = `<span class="chat-summary-meta-line"><i class="fa-solid fa-user"></i> ${escapeHtml(currentReport.playerName || '')}`;
        if (currentReport.steamName) {
            meta += ` <span class="chat-steam">(${escapeHtml(currentReport.steamName)})</span>`;
        }
        const knowsPresence = currentReport.reporterOnline === true || currentReport.reporterOnline === false;
        const online = currentReport.reporterOnline === true;
        const liveId = currentReport.reporterServerId != null ? currentReport.reporterServerId : currentReport.serverId;
        if (online && liveId) {
            meta += ` <span class="chat-serverid">[ID:${liveId}]</span>`;
        }
        if (knowsPresence) {
            const statusClass = online ? 'reporter-live' : 'reporter-offline';
            const statusLabel = online ? T('ui_online') : T('ui_offline');
            meta += ` <span class="reporter-presence ${statusClass}"><span class="presence-dot"></span>${statusLabel}</span>`;
        }
        if (currentReport.adminName) {
            meta += ` · <i class="fa-solid fa-shield-halved"></i> ${escapeHtml(currentReport.adminName)}`;
        }
        meta += '</span>';

        adminSummaryEl.innerHTML = `
            <div class="chat-summary-label"><i class="fa-solid fa-align-left"></i> ${escapeHtml(T('ui_chat_summary_label'))}</div>
            <div class="chat-summary-head">
                <span class="chat-prio-badge ${prioClass}">${prioLabel}</span>
            </div>
            <div class="chat-summary-desc">${desc}</div>
            <div class="chat-summary-meta">${meta}</div>
        `;
    } else if (adminSummaryEl) {
        adminSummaryEl.classList.add('hidden');
    }

    const isClosed = currentReport.status === 'Cerrado';

    // Configurar menú de opciones
    if (isClosed) {
        chatOptionsBtn.classList.add('hidden');
        document.getElementById('chat-input-area').classList.add('hidden');
    } else {
        chatOptionsBtn.classList.remove('hidden');
        document.getElementById('chat-input-area').classList.remove('hidden');

        // Admin ve llamar, Jugador solo ve cerrar
        if (isAdminContext) {
            document.getElementById('call-btn').classList.remove('hidden');
        } else {
            document.getElementById('call-btn').classList.add('hidden');
        }
    }

    const msgsContainer = document.getElementById('chat-messages');
    msgsContainer.innerHTML = '';
    if (messagesData) {
        messagesData.forEach(m => appendMessage(m.sender, m.message, m.is_admin, m.created_at));
    }
}

function appendMessage(senderStr, text, is_admin, timestamp) {
    const msgsContainer = document.getElementById('chat-messages');
    const msgDiv = document.createElement('div');

    const isMe = (isAdminContext && is_admin) || (!isAdminContext && !is_admin);
    msgDiv.className = `msg ${isMe ? 'msg-player' : 'msg-admin'}`;

    const parsed = parseSender(senderStr, is_admin);

    let innerContent = '';
    if (!isMe) {
        if (is_admin) {
            // Mostrar quién del staff está hablando
            innerContent += `<span class="msg-sender staff-sender"><i class="fa-solid fa-shield-halved"></i> ${parsed.label}`;
            if (parsed.steam) innerContent += ` <span class="msg-sender-steam">(${parsed.steam})</span>`;
            if (parsed.id) innerContent += ` <span class="msg-sender-id">[ID:${parsed.id}]</span>`;
            innerContent += `</span>`;
        } else {
            // Jugador hablando (admin viendo)
            innerContent += `<span class="msg-sender"><i class="fa-solid fa-user"></i> ${parsed.label}`;
            if (parsed.steam) innerContent += ` <span class="msg-sender-steam">(${parsed.steam})</span>`;
            if (parsed.id) innerContent += ` <span class="msg-sender-id">[ID:${parsed.id}]</span>`;
            innerContent += `</span>`;
        }
    } else if (is_admin && isAdminContext) {
        // Soy yo (admin) el que habla - mostrar mi propio nombre
        innerContent += `<span class="msg-sender self-sender"><i class="fa-solid fa-shield-halved"></i> ${parsed.label}`;
        if (parsed.id) innerContent += ` <span class="msg-sender-id">[ID:${parsed.id}]</span>`;
        innerContent += `</span>`;
    }

    innerContent += `<span class="msg-text">${escapeHtml(text)}</span>`;

    // Añadimos la hora relativa
    if (timestamp) {
        innerContent += `<span class="msg-time">${timeAgo(timestamp)}</span>`;
        msgDiv.style.marginBottom = "14px";
    }

    msgDiv.innerHTML = innerContent;

    msgsContainer.appendChild(msgDiv);
    msgsContainer.scrollTop = msgsContainer.scrollHeight;
}

document.getElementById('send-msg-btn').addEventListener('click', sendMessage);
document.getElementById('chat-input').addEventListener('keypress', (e) => {
    if (e.key === 'Enter') sendMessage();
});

function sendMessage() {
    const input = document.getElementById('chat-input');
    const text = input.value.trim();
    if (text === '') return;

    post('sendChatMessage', {
        reportId: currentReport.id,
        message: text,
        isAdmin: isAdminContext
    });
    input.value = '';
}

// Botones del menú
document.getElementById('call-btn').addEventListener('click', () => {
    post('callPlayer', { reportId: currentReport.id });
    chatOptionsMenu.classList.add('hidden');
});

document.getElementById('close-report-btn').addEventListener('click', () => {
    post('closeReport', { reportId: currentReport.id }).then(() => {
        chatOptionsMenu.classList.add('hidden');
        post('closeUI');
    });
});

// ==========================================
// PANEL ADMIN (SEGMENTED CONTROL)
// ==========================================
document.querySelectorAll('.segment-btn').forEach(btn => {
    btn.addEventListener('click', (e) => {
        const el = e.target.closest('.segment-btn');
        if (!el) return;
        document.querySelectorAll('.segment-btn').forEach(b => b.classList.remove('active'));
        el.classList.add('active');

        document.querySelectorAll('.tab-content').forEach(c => c.classList.add('hidden'));
        const tabId = el.getAttribute('data-tab');
        document.getElementById(tabId).classList.remove('hidden');

        if (tabId === 'active-reports') loadAdminReports();
        if (tabId === 'history-reports') loadAdminHistory();
    });
});

let cachedActiveReports = [];
let cachedHistoryReports = [];

// Búsqueda Dinámica
document.getElementById('search-input').addEventListener('input', (e) => {
    const searchTerm = e.target.value.toLowerCase();
    const activeSeg = document.querySelector('.segment-btn.active');
    const activeTabId = activeSeg ? activeSeg.getAttribute('data-tab') : 'active-reports';

    if (activeTabId === 'active-reports') {
        renderActiveReports(searchTerm);
    } else {
        renderHistoryReports(searchTerm);
    }
});

async function loadAdminReports() {
    const container = document.getElementById('active-reports');
    container.innerHTML = `<p style="color:white; text-align:center; margin-top:20px;">${escapeHtml(T('ui_loading'))}</p>`;
    cachedActiveReports = await post('loadReports').then(r => r.json());
    renderActiveReports('');
}

function renderActiveReports(filterText) {
    const container = document.getElementById('active-reports');
    container.innerHTML = '';

    const filtered = cachedActiveReports.filter(r =>
        (r.playerName || '').toLowerCase().includes(filterText) ||
        (r.steamName || '').toLowerCase().includes(filterText) ||
        r.title.toLowerCase().includes(filterText) ||
        r.id.toString().includes(filterText) ||
        (r.serverId && r.serverId.toString().includes(filterText))
    );

    if (filtered.length === 0) {
        container.innerHTML = `<p style="text-align:center; color:#888; margin-top:20px;">${escapeHtml(T('ui_no_active'))}</p>`;
        return;
    }

    filtered.forEach(rep => {
        const card = document.createElement('div');
        const knowsPresence = rep.reporterOnline === true || rep.reporterOnline === false;
        card.className = 'report-card ui-sound' + (rep.reporterOnline === false ? ' card-reporter-offline' : '');
        card.setAttribute('data-sound', 'hover');

        const isProgress = rep.status === 'En progreso';
        const buttonText = isProgress ? T('ui_btn_view_chat') : T('ui_btn_take');
        const buttonClass = isProgress ? 'btn-take' : 'btn-take active-rep';

        const online = rep.reporterOnline === true;
        const liveId = rep.reporterServerId != null ? rep.reporterServerId : rep.serverId;
        let playerInfo = rep.playerName || T('ui_player_default');
        let extraInfo = '';
        if (rep.steamName) extraInfo += `<span class="card-steam">(${rep.steamName})</span> `;
        if (online && liveId) {
            extraInfo += `<span class="card-serverid">[ID:${liveId}]</span>`;
        }

        let presence = '';
        if (knowsPresence) {
            const presenceClass = online ? 'presence-live' : 'presence-offline';
            const presenceLabel = online ? T('ui_online') : T('ui_offline');
            presence = `<span class="card-presence ${presenceClass}"><span class="presence-dot"></span>${escapeHtml(presenceLabel)}</span>`;
        }

        let staffInfo = '';
        if (isProgress && rep.adminName) {
            staffInfo = `<span class="card-staff-attending"><i class="fa-solid fa-shield-halved"></i> ${escapeHtml(T('ui_attended_by'))} ${escapeHtml(rep.adminName)}</span>`;
        }

        card.innerHTML = `
            <div class="report-info">
                <h4>#${rep.id} - ${escapeHtml(String(rep.title || ''))}</h4>
                <p class="card-player-line"><i class="fa-solid fa-user"></i> ${escapeHtml(String(playerInfo))} ${extraInfo} ${presence}</p>
                <p class="card-status-line">${escapeHtml(trStatus(rep.status))} ${staffInfo}</p>
            </div>
            <button class="${buttonClass}">${buttonText}</button>
        `;

        const btn = card.querySelector('button');
        btn.addEventListener('click', () => {
            if (!isProgress) {
                // Si está abierto, asignarselo al admin
                post('takeReport', { reportId: rep.id }).then(() => {
                    post('openAdminChat', { reportId: rep.id, report: { ...rep, status: 'En progreso' } });
                });
            } else {
                // Entrar a observar
                post('openAdminChat', { reportId: rep.id, report: rep });
            }
        });

        container.appendChild(card);
    });
}

async function loadAdminHistory() {
    const container = document.getElementById('history-reports');
    container.innerHTML = `<p style="color:white; text-align:center; margin-top:20px;">${escapeHtml(T('ui_loading'))}</p>`;
    cachedHistoryReports = await post('loadHistory').then(r => r.json());
    renderHistoryReports('');
}

function renderHistoryReports(filterText) {
    const container = document.getElementById('history-reports');
    container.innerHTML = '';

    const filtered = cachedHistoryReports.filter(r =>
        (r.playerName || '').toLowerCase().includes(filterText) ||
        (r.steamName || '').toLowerCase().includes(filterText) ||
        r.title.toLowerCase().includes(filterText) ||
        r.id.toString().includes(filterText) ||
        (r.adminName || '').toLowerCase().includes(filterText) ||
        (r.closed_by_name || '').toLowerCase().includes(filterText) ||
        (r.close_reason || '').toLowerCase().includes(filterText)
    );

    if (filtered.length === 0) {
        container.innerHTML = `<p style="text-align:center; color:#888; margin-top:20px;">${escapeHtml(T('ui_no_history'))}</p>`;
        return;
    }

    filtered.forEach(rep => {
        const card = document.createElement('div');
        card.className = 'report-card ui-sound';
        card.setAttribute('data-sound', 'hover');

        let extraInfo = '';
        if (rep.steamName) extraInfo += `<span class="card-steam">(${rep.steamName})</span> `;
        if (rep.serverId) extraInfo += `<span class="card-serverid">[ID:${rep.serverId}]</span>`;

        let staffLine = '';
        if (rep.adminName) {
            staffLine = `<br><i class="fa-solid fa-shield-halved"></i> ${escapeHtml(T('ui_attended_by'))} <span class="card-staff-name">${escapeHtml(rep.adminName)}</span>`;
        }

        let closeLine = '';
        if (rep.close_reason === 'inactivity') {
            closeLine = `<p class="history-close history-close-inactivity"><i class="fa-solid fa-moon"></i> ${escapeHtml(Tfmt('ui_history_closed_inactivity', autoCloseOfflineMinutes))}</p>`;
        } else if (rep.close_reason === 'staff' && rep.closed_by_name) {
            closeLine = `<p class="history-close history-close-by"><span class="history-close-label">${escapeHtml(T('ui_history_closed_staff'))}</span> <span class="history-closer-name">${escapeHtml(rep.closed_by_name)}</span></p>`;
        } else if (rep.close_reason === 'player') {
            if (rep.closed_by_name) {
                closeLine = `<p class="history-close history-close-by"><span class="history-close-label">${escapeHtml(T('ui_history_closed_user'))}</span> <span class="history-closer-name">${escapeHtml(rep.closed_by_name)}</span></p>`;
            } else {
                closeLine = `<p class="history-close history-close-by">${escapeHtml(T('ui_history_closed_user_fallback'))}</p>`;
            }
        } else if (rep.status === 'Cerrado') {
            closeLine = `<p class="history-close history-close-legacy">${escapeHtml(T('ui_history_legacy'))}</p>`;
        }

        card.innerHTML = `
            <div class="report-info">
                <h4>#${rep.id} - ${escapeHtml(String(rep.title || ''))}</h4>
                <p><i class="fa-solid fa-user"></i> ${escapeHtml(String(rep.playerName || ''))} ${extraInfo} · <i class="fa-regular fa-clock"></i> ${new Date(rep.updated_at).toLocaleDateString()}${staffLine}</p>
                ${closeLine}
            </div>
            <button class="btn-take ui-sound" data-sound="click">${escapeHtml(T('ui_review'))}</button>
        `;
        card.querySelector('.btn-take').addEventListener('click', () => {
            post('openAdminChat', { reportId: rep.id, report: rep });
        });
        container.appendChild(card);
    });
}

// ==========================================
// LLAMADAS (UI LOGIC)
// ==========================================
let callInterval = null;
let callSeconds = 0;

function startCallTimer() {
    callSeconds = 0;
    const timerUI = document.getElementById('call-timer');
    timerUI.innerText = "00:00";

    if (callInterval) clearInterval(callInterval);
    callInterval = setInterval(() => {
        callSeconds++;
        const mins = String(Math.floor(callSeconds / 60)).padStart(2, '0');
        const secs = String(callSeconds % 60).padStart(2, '0');
        timerUI.innerText = `${mins}:${secs}`;
    }, 1000);
}

function stopCallTimer() {
    if (callInterval) clearInterval(callInterval);
}

document.getElementById('answer-call-btn').addEventListener('click', () => {
    post('answerCall', { reportId: incomingCallReportId });
});

document.getElementById('decline-call-btn').addEventListener('click', () => {
    post('declineCall', { reportId: incomingCallReportId });
    incomingCallModal.classList.add('hidden');
    checkAndCloseEmptyUI();
});

document.getElementById('hangup-call-btn').addEventListener('click', () => {
    const activeReportId = currentReport ? currentReport.id : incomingCallReportId;
    post('hangUpCall', { reportId: activeReportId });
});
