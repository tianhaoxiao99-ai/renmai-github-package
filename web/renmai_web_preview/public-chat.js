(function () {
    const PUBLIC_CONFIG_ENDPOINT = '/api/public-config';
    const LOCAL_PUBLIC_CONFIG_ENDPOINT = './public-config.local.json';
    const LOCAL_SUPABASE_BROWSER_URL = './vendor/supabase.min.js';
    const PUBLIC_AUTH_FLOW_STORAGE_KEY = 'renmai-public-auth-flow-v1';
    const AUTH_RESEND_COOLDOWN_MS = 60000;

    const publicRuntime = {};
    const realtimeState = {};
    let authPending = false;
    let authVerificationTimer = null;
    let supabaseLibraryPromise = null;

    if (typeof window !== 'undefined') {
        window.__RENMAI_PUBLIC_CHAT_LOADED__ = true;
    }

    function createDefaultPublicRuntime() {
        return {
            checked: false,
            loading: false,
            supabaseEnabled: false,
            supabaseUrl: '',
            supabaseAnonKey: '',
            libraryLoaded: false,
            error: '',
        };
    }

    function createDefaultRealtimeState() {
        return {
            client: null,
            session: null,
            profile: null,
            authSubscription: null,
            messageChannel: null,
            subscribedConversationId: null,
            selectedConversationId: null,
            conversations: [],
            conversationsLoading: false,
            messagesByConversation: {},
            messageDrafts: {},
            messageLoading: false,
            sending: false,
            directoryQuery: '',
            directory: [],
            directoryLoading: false,
            error: '',
            initializing: false,
        };
    }

    function createDefaultPublicAuthFlow() {
        return {
            flowType: '',
            stage: '',
            email: '',
            displayName: '',
            roleTitle: '',
            remember: true,
            resendAvailableAt: 0,
            feedback: '',
            feedbackType: '',
        };
    }

    Object.assign(publicRuntime, createDefaultPublicRuntime());
    Object.assign(realtimeState, createDefaultRealtimeState());
    var mode = '';
    var publicAuthFlow = createDefaultPublicAuthFlow();
    publicAuthFlow = loadPublicAuthFlow();

    function isRealtimeConfigured() {
        return Boolean(publicRuntime.supabaseEnabled && realtimeState.client);
    }

    function hasRealtimeSession() {
        return Boolean(realtimeState.session?.user?.id);
    }

    function getRealtimeDisplayName(profile = realtimeState.profile, session = realtimeState.session) {
        const email = String(session?.user?.email || '').trim();
        const fallback = email ? email.split('@')[0] : '在线用户';
        return String(profile?.display_name || session?.user?.user_metadata?.display_name || fallback || '在线用户').trim();
    }

    function getRealtimeRoleTitle(profile = realtimeState.profile, session = realtimeState.session) {
        return String(profile?.role_title || session?.user?.user_metadata?.role_title || '公开账号').trim();
    }

    function getRealtimeHandle(profile = realtimeState.profile, session = realtimeState.session) {
        if (profile?.handle) return String(profile.handle).trim();
        const seed = String(session?.user?.id || 'guest').replace(/[^a-z0-9]/gi, '').toLowerCase();
        return `renmai-${seed.slice(0, 8) || 'guest'}`;
    }

    function sanitizeRealtimeSearch(value) {
        return String(value || '')
            .trim()
            .replace(/[,%]/g, ' ')
            .replace(/\s+/g, ' ')
            .slice(0, 32);
    }

    function slugifyHandleSeed(value) {
        const lower = String(value || '').toLowerCase();
        const ascii = lower
            .replace(/[^a-z0-9_-]+/g, '-')
            .replace(/^-+|-+$/g, '')
            .replace(/-{2,}/g, '-');
        return ascii.slice(0, 18) || 'renmai';
    }

    function buildPublicHandle(name, userId) {
        const suffix = String(userId || '').replace(/[^a-z0-9]/gi, '').toLowerCase().slice(0, 8) || 'user';
        const prefix = slugifyHandleSeed(name);
        return `${prefix}-${suffix}`.slice(0, 32);
    }

    function buildPublicAuthRedirect() {
        if (typeof window === 'undefined' || !window.location) return undefined;
        return `${window.location.origin}${window.location.pathname}`;
    }

    function sanitizePublicAuthFlow(raw = {}) {
        const next = createDefaultPublicAuthFlow();
        const flowType = String(raw.flowType || '').trim();
        const stage = String(raw.stage || '').trim();
        if (!['signup', 'recovery'].includes(flowType)) return next;
        next.flowType = flowType;
        next.stage = stage || 'code';
        next.email = String(raw.email || '').trim().slice(0, 120);
        next.displayName = String(raw.displayName || '').trim().slice(0, 48);
        next.roleTitle = String(raw.roleTitle || '').trim().slice(0, 72);
        next.remember = raw.remember !== false;
        next.resendAvailableAt = Number(raw.resendAvailableAt || 0) || 0;
        next.feedback = String(raw.feedback || '').trim();
        next.feedbackType = String(raw.feedbackType || '').trim();
        return next;
    }

    function loadPublicAuthFlow() {
        if (
            (mode === 'register' && publicAuthFlow.flowType === 'signup' && hasPendingPublicAuthFlow())
            || (mode === 'reset-request' && publicAuthFlow.flowType === 'recovery' && hasPendingPublicAuthFlow())
        ) {
            authState.ui.feedback = '验证码已经发出，请直接在下方填写，不需要重复提交。';
            authState.ui.feedbackType = 'success';
            persistAuthState();
            authPending = false;
            renderEntryState();
            return;
        }

        try {
            const raw = sessionStorage.getItem(PUBLIC_AUTH_FLOW_STORAGE_KEY);
            if (!raw) return createDefaultPublicAuthFlow();
            return sanitizePublicAuthFlow(JSON.parse(raw));
        } catch (_) {
            return createDefaultPublicAuthFlow();
        }
    }

    function persistPublicAuthFlow() {
        const sanitized = sanitizePublicAuthFlow(publicAuthFlow);
        publicAuthFlow = sanitized;
        if (!publicAuthFlow.flowType) {
            try {
                sessionStorage.removeItem(PUBLIC_AUTH_FLOW_STORAGE_KEY);
            } catch (_) {
                // ignore
            }
            return;
        }
        try {
            sessionStorage.setItem(PUBLIC_AUTH_FLOW_STORAGE_KEY, JSON.stringify({
                flowType: publicAuthFlow.flowType,
                stage: publicAuthFlow.stage,
                email: publicAuthFlow.email,
                displayName: publicAuthFlow.displayName,
                roleTitle: publicAuthFlow.roleTitle,
                remember: publicAuthFlow.remember,
                resendAvailableAt: publicAuthFlow.resendAvailableAt,
                feedback: publicAuthFlow.feedback,
                feedbackType: publicAuthFlow.feedbackType,
            }));
        } catch (_) {
            // ignore
        }
    }

    function clearPublicAuthFlow() {
        publicAuthFlow = createDefaultPublicAuthFlow();
        persistPublicAuthFlow();
        stopAuthVerificationTimer();
    }

    function hasPendingPublicAuthFlow() {
        return Boolean(publicAuthFlow.flowType && publicAuthFlow.email);
    }

    function isRecoveryPasswordStage() {
        return publicAuthFlow.flowType === 'recovery' && publicAuthFlow.stage === 'reset-password';
    }

    function shouldHoldRealtimeSession() {
        if (publicAuthFlow.flowType === 'signup') {
            return ['signup-pending', 'code', 'verify-signup'].includes(publicAuthFlow.stage);
        }
        return publicAuthFlow.flowType === 'recovery'
            && ['code', 'verify-recovery', 'reset-password'].includes(publicAuthFlow.stage);
    }

    function getAuthResendCountdownSeconds() {
        return Math.max(0, Math.ceil((publicAuthFlow.resendAvailableAt - Date.now()) / 1000));
    }

    function maskEmailAddress(value) {
        const email = String(value || '').trim();
        const atIndex = email.indexOf('@');
        if (atIndex <= 1) return email;
        const name = email.slice(0, atIndex);
        const domain = email.slice(atIndex);
        if (name.length <= 2) return `${name[0]}*${domain}`;
        return `${name.slice(0, 2)}***${name.slice(-1)}${domain}`;
    }

    function syncAuthModeWithPublicFlow() {
        if (!publicRuntime.supabaseEnabled) return;
        if (publicAuthFlow.flowType === 'signup') {
            authState.ui.mode = 'register';
        } else if (publicAuthFlow.flowType === 'recovery') {
            authState.ui.mode = 'reset-request';
        }
    }

    async function unsubscribeRealtimeChannel() {
        const channel = realtimeState.messageChannel;
        realtimeState.messageChannel = null;
        realtimeState.subscribedConversationId = null;
        if (channel && typeof channel.unsubscribe === 'function') {
            try {
                await channel.unsubscribe();
            } catch (_) {
                // ignore
            }
        }
    }

    function clearRealtimeSessionState(options = {}) {
        void unsubscribeRealtimeChannel();
        realtimeState.session = null;
        realtimeState.profile = null;
        realtimeState.subscribedConversationId = null;
        realtimeState.selectedConversationId = null;
        realtimeState.conversations = [];
        realtimeState.conversationsLoading = false;
        realtimeState.messagesByConversation = {};
        realtimeState.messageDrafts = {};
        realtimeState.messageLoading = false;
        realtimeState.sending = false;
        realtimeState.directory = [];
        realtimeState.directoryLoading = false;
        realtimeState.error = '';
        if (!options.keepClient) {
            realtimeState.client = null;
            realtimeState.authSubscription = null;
        }
    }

    function normalizeRealtimeConversation(item) {
        if (!item) return null;
        return {
            id: String(item.conversation_id || item.id || ''),
            updatedAt: String(item.updated_at || ''),
            lastMessageAt: String(item.last_message_at || item.updated_at || ''),
            lastMessagePreview: String(item.last_message_preview || '').trim(),
            partnerId: String(item.partner_id || ''),
            partnerDisplayName: String(item.partner_display_name || '未命名联系人').trim(),
            partnerHandle: String(item.partner_handle || '').trim(),
            partnerRoleTitle: String(item.partner_role_title || '').trim(),
        };
    }

    function getSelectedRealtimeConversation() {
        return realtimeState.conversations.find((item) => item.id === realtimeState.selectedConversationId)
            || realtimeState.conversations[0]
            || null;
    }

    function getRealtimeDraft(conversationId) {
        if (!conversationId) return '';
        return String(realtimeState.messageDrafts?.[conversationId] || '');
    }

    function setRealtimeDraft(conversationId, value) {
        if (!conversationId) return;
        realtimeState.messageDrafts = {
            ...(realtimeState.messageDrafts || {}),
            [conversationId]: String(value || ''),
        };
    }

    function clearRealtimeDraft(conversationId) {
        if (!conversationId) return;
        const next = { ...(realtimeState.messageDrafts || {}) };
        delete next[conversationId];
        realtimeState.messageDrafts = next;
    }

    function autoResizeRealtimeComposer() {
        const input = document.getElementById('realtime-composer');
        if (!input) return;
        input.style.height = 'auto';
        input.style.height = `${Math.min(input.scrollHeight, 180)}px`;
    }

    function formatRealtimeTime(value) {
        if (!value) return '刚刚';
        const date = new Date(value);
        if (Number.isNaN(date.getTime())) return '刚刚';
        return date.toLocaleString('zh-CN', {
            month: '2-digit',
            day: '2-digit',
            hour: '2-digit',
            minute: '2-digit',
        });
    }

    function getRealtimeCurrentUser() {
        if (!hasRealtimeSession()) return null;
        const session = realtimeState.session;
        return {
            id: String(session.user.id || ''),
            name: getRealtimeDisplayName(),
            identifier: String(session.user.email || ''),
            role: getRealtimeRoleTitle(),
            handle: getRealtimeHandle(),
        };
    }

    function clearLegacyLocalAuthForPublicMode() {
        if (typeof authState !== 'object' || !authState) return;
        const demoUsers = Array.isArray(authState.users)
            ? authState.users.filter((item) => String(item?.identifier || '').toLowerCase() === 'demo@renmai.app')
            : [];
        const nextUsers = demoUsers.length
            ? demoUsers
            : (Array.isArray(defaultAuthState?.users) ? defaultAuthState.users : []);
        authState.users = nextUsers;
        if (String(authState.ui?.feedback || '').includes('账号已经存在')) {
            authState.ui.feedback = '';
            authState.ui.feedbackType = '';
        }
        persistAuthState();
    }

    // SECTION_STATE
    const legacyGetCurrentUser = getCurrentUser;
    getCurrentUser = function () {
        return getRealtimeCurrentUser() || legacyGetCurrentUser();
    };

    const legacyHasActiveSession = hasActiveSession;
    hasActiveSession = function () {
        return Boolean(getRealtimeCurrentUser()) || legacyHasActiveSession();
    };

    function mapSupabaseAuthError(error) {
        const raw = String(error?.message || error?.error_description || error?.code || '在线认证失败').trim();
        const normalized = raw.toLowerCase();
        if (normalized.includes('invalid login credentials')) return '账号或密码不正确。';
        if (normalized.includes('email not confirmed')) return '请先去邮箱确认后再登录。';
        if (normalized.includes('user already registered')) return '这个邮箱已经注册过了，直接登录即可。';
        if (normalized.includes('signup requires a valid password')) return '密码至少需要 6 位。';
        if (normalized.includes('email rate limit')) return '请求太频繁了，请稍后再试。';
        if (normalized.includes('network')) return '网络连接失败，请稍后重试。';
        return raw;
    }

    function withTimeout(promise, timeoutMs, label) {
        return new Promise((resolve, reject) => {
            const timer = setTimeout(() => {
                reject(new Error(label || 'request_timeout'));
            }, timeoutMs);
            Promise.resolve(promise)
                .then((value) => {
                    clearTimeout(timer);
                    resolve(value);
                })
                .catch((error) => {
                    clearTimeout(timer);
                    reject(error);
                });
        });
    }

    function loadExternalScript(src) {
        return new Promise((resolve, reject) => {
            if (typeof document === 'undefined') {
                reject(new Error('document_unavailable'));
                return;
            }
            const existing = document.querySelector(`script[data-renmai-src="${src}"]`);
            if (existing?.dataset.loaded === 'true') {
                resolve();
                return;
            }
            if (existing) {
                existing.addEventListener('load', () => resolve(), { once: true });
                existing.addEventListener('error', () => reject(new Error('script_load_failed')), { once: true });
                return;
            }
            const script = document.createElement('script');
            script.src = src;
            script.async = true;
            script.dataset.renmaiSrc = src;
            script.addEventListener('load', () => {
                script.dataset.loaded = 'true';
                resolve();
            }, { once: true });
            script.addEventListener('error', () => reject(new Error('script_load_failed')), { once: true });
            document.head.appendChild(script);
        });
    }

    async function loadSupabaseCreateClient() {
        if (supabaseLibraryPromise) return supabaseLibraryPromise;
        supabaseLibraryPromise = (async () => {
            if (typeof window !== 'undefined' && typeof window.supabase?.createClient === 'function') {
                return window.supabase.createClient.bind(window.supabase);
            }

            await withTimeout(loadExternalScript(LOCAL_SUPABASE_BROWSER_URL), 8000, 'supabase_script_timeout');

            if (typeof window !== 'undefined' && typeof window.supabase?.createClient === 'function') {
                return window.supabase.createClient.bind(window.supabase);
            }
            throw new Error('supabase_client_unavailable');
        })();
        return supabaseLibraryPromise;
    }

    mapSupabaseAuthError = function (error) {
        const raw = String(error?.message || error?.error_description || error?.code || '在线认证失败').trim();
        const normalized = raw.toLowerCase();
        if (normalized.includes('invalid login credentials')) return '账号或密码不正确。';
        if (normalized.includes('email not confirmed')) return '请先去邮箱完成验证码确认后再登录。';
        if (normalized.includes('user already registered')) return '这个邮箱已经注册过了，直接登录即可。';
        if (normalized.includes('signup requires a valid password')) return '密码至少需要 6 位。';
        if (normalized.includes('email rate limit')) return '请求太频繁了，请稍后再试。';
        if (normalized.includes('token has expired') || normalized.includes('otp has expired')) return '验证码已过期，请重新发送。';
        if (normalized.includes('invalid otp') || normalized.includes('token is invalid')) return '验证码不正确，请检查后再试。';
        if (normalized.includes('same password')) return '新密码不能和旧密码相同。';
        if (normalized.includes('password should be at least')) return '新密码至少需要 6 位。';
        if (normalized.includes('network')) return '网络连接失败，请稍后重试。';
        return raw;
    };

    const baseRealtimeAuthErrorMapper = mapSupabaseAuthError;
    mapSupabaseAuthError = function (error) {
        const raw = String(error?.message || error?.error_description || error?.code || '').trim();
        const normalized = raw.toLowerCase();
        if (normalized.includes('for security purposes')) {
            return '操作太频繁了，请等待倒计时结束后再重新发送验证码。';
        }
        return baseRealtimeAuthErrorMapper(error);
    };

    function stopAuthVerificationTimer() {
        if (authVerificationTimer) {
            clearInterval(authVerificationTimer);
            authVerificationTimer = null;
        }
    }

    function startAuthVerificationTimer() {
        stopAuthVerificationTimer();
        if (!hasPendingPublicAuthFlow()) return;
        authVerificationTimer = window.setInterval(() => {
            if (!hasPendingPublicAuthFlow()) {
                stopAuthVerificationTimer();
                return;
            }
            renderAuthVerificationModal();
        }, 1000);
    }

    function setPublicAuthFlowFeedback(message, type = '') {
        publicAuthFlow.feedback = String(message || '').trim();
        publicAuthFlow.feedbackType = type;
        persistPublicAuthFlow();
        renderAuthVerificationModal();
    }

    function openAuthVerificationModal() {
        const modal = document.getElementById('auth-verification-modal');
        if (!modal) return;
        modal.classList.add('open');
        modal.setAttribute('aria-hidden', 'false');
        renderAuthVerificationModal();
        startAuthVerificationTimer();
    }

    function closeAuthVerificationModal() {
        const modal = document.getElementById('auth-verification-modal');
        if (!modal) return;
        modal.classList.remove('open');
        modal.setAttribute('aria-hidden', 'true');
        stopAuthVerificationTimer();
    }

    function renderAuthVerificationModal() {
        const modal = document.getElementById('auth-verification-modal');
        const title = document.getElementById('auth-verification-title');
        const copy = document.getElementById('auth-verification-copy');
        const body = document.getElementById('auth-verification-body');
        const footer = document.getElementById('auth-verification-footer');
        if (!modal || !title || !copy || !body || !footer) return;
        if (!hasPendingPublicAuthFlow()) {
            body.innerHTML = '';
            footer.innerHTML = '';
            closeAuthVerificationModal();
            return;
        }

        const isSignup = publicAuthFlow.flowType === 'signup';
        const isResetPassword = isRecoveryPasswordStage();
        const countdown = getAuthResendCountdownSeconds();
        const canResend = countdown <= 0;
        const feedbackClass = publicAuthFlow.feedbackType === 'success' ? 'auth-modal-feedback success' : 'auth-modal-feedback';

        if (isResetPassword) {
            title.textContent = '设置新密码';
            copy.textContent = `邮箱 ${maskEmailAddress(publicAuthFlow.email)} 已验证成功，请设置一个新的登录密码。`;
            body.innerHTML = `
                <form class="auth-modal-stack" id="auth-reset-password-form">
                    <div class="auth-modal-note">验证码已经通过，完成密码重置后，需要重新用新密码登录仁迈。</div>
                    <div class="field">
                        <label for="auth-reset-password">新密码</label>
                        <input class="input" id="auth-reset-password" name="password" type="password" maxlength="40" placeholder="至少 6 位">
                    </div>
                    <div class="field">
                        <label for="auth-reset-password-confirm">确认新密码</label>
                        <input class="input" id="auth-reset-password-confirm" name="confirmPassword" type="password" maxlength="40" placeholder="再次输入新密码">
                    </div>
                    <div class="${feedbackClass}" id="auth-verification-feedback">${escapeHtml(publicAuthFlow.feedback || '')}</div>
                </form>
            `;
            footer.innerHTML = `
                <button class="ghost-btn" data-action="cancel-auth-flow" type="button">取消</button>
                <button class="solid-btn" data-action="submit-auth-reset-password" type="button">保存新密码</button>
            `;
            return;
        }

        title.textContent = isSignup ? '输入注册验证码' : '验证邮箱';
        copy.textContent = isSignup
            ? `验证码已经发送到 ${maskEmailAddress(publicAuthFlow.email)}，验证成功后才能进入仁迈。`
            : `找回密码验证码已经发送到 ${maskEmailAddress(publicAuthFlow.email)}，验证成功后才能继续设置新密码。`;
        body.innerHTML = `
            <form class="auth-modal-stack" id="auth-verification-form">
                <div class="auth-modal-note">
                    ${isSignup
                        ? '如果没有收到邮件，请检查垃圾箱，并确认 Supabase 已开启 Confirm email、自有 SMTP 和 OTP 邮件模板。'
                        : '这一步只验证邮箱归属，不会直接进入主应用。验证码通过后，还需要再设置一次新密码。'}
                </div>
                <div class="field">
                    <label for="auth-verification-code">邮箱验证码</label>
                    <input class="input auth-code-input" id="auth-verification-code" name="otp" inputmode="numeric" autocomplete="one-time-code" maxlength="12" placeholder="请输入邮件中的验证码">
                </div>
                <div class="auth-modal-meta">
                    <span>${isSignup ? '注册验证码' : '找回密码验证码'}仅用于当前邮箱</span>
                    <span>${canResend ? '现在可以重新发送' : `${countdown}s 后可重新发送`}</span>
                </div>
                <div class="${feedbackClass}" id="auth-verification-feedback">${escapeHtml(publicAuthFlow.feedback || '')}</div>
            </form>
        `;
        footer.innerHTML = `
            <button class="ghost-btn" data-action="cancel-auth-flow" type="button">返回修改邮箱</button>
            <button class="ghost-btn" data-action="resend-auth-otp" type="button" ${canResend ? '' : 'disabled'}>${canResend ? '重新发送' : `${countdown}s 后重发`}</button>
            <button class="solid-btn" data-action="submit-auth-verification" type="button">${isSignup ? '验证并进入' : '验证并继续'}</button>
        `;
    }

    function buildAuthVerificationView() {
        if (!hasPendingPublicAuthFlow()) return null;

        const isSignup = publicAuthFlow.flowType === 'signup';
        const isResetPassword = isRecoveryPasswordStage();
        const countdown = getAuthResendCountdownSeconds();
        const canResend = countdown <= 0;
        const feedbackClass = publicAuthFlow.feedbackType === 'success' ? 'auth-modal-feedback success' : 'auth-modal-feedback';

        if (isResetPassword) {
            return {
                title: '设置新密码',
                copy: `邮箱 ${maskEmailAddress(publicAuthFlow.email)} 已验证成功，请设置一个新的登录密码。`,
                body: `
                    <form class="auth-modal-stack" id="auth-reset-password-form">
                        <div class="auth-modal-note">验证码已经通过，完成密码重置后，需要重新用新密码登录仁迈。</div>
                        <div class="field">
                            <label for="auth-reset-password">新密码</label>
                            <input class="input" id="auth-reset-password" name="password" type="password" maxlength="40" placeholder="至少 6 位">
                        </div>
                        <div class="field">
                            <label for="auth-reset-password-confirm">确认新密码</label>
                            <input class="input" id="auth-reset-password-confirm" name="confirmPassword" type="password" maxlength="40" placeholder="再次输入新密码">
                        </div>
                        <div class="${feedbackClass}" id="auth-verification-feedback">${escapeHtml(publicAuthFlow.feedback || '')}</div>
                    </form>
                `,
                footer: `
                    <button class="ghost-btn" data-action="cancel-auth-flow" type="button">取消</button>
                    <button class="solid-btn" data-action="submit-auth-reset-password" type="button">保存新密码</button>
                `,
            };
        }

        return {
            title: isSignup ? '输入注册验证码' : '验证邮箱',
            copy: isSignup
                ? `验证码已经发送到 ${maskEmailAddress(publicAuthFlow.email)}，验证通过后才能继续。`
                : `找回密码验证码已经发送到 ${maskEmailAddress(publicAuthFlow.email)}，验证通过后才能继续设置新密码。`,
            body: `
                <form class="auth-modal-stack" id="auth-verification-form">
                    <div class="auth-modal-note">
                        ${isSignup
                            ? '现在直接在注册栏里输入邮件中的验证码就可以，不用再找弹窗。'
                            : '验证码只用于确认当前邮箱归属，验证成功后还需要再设置一次新密码。'}
                    </div>
                    <div class="field">
                        <label for="auth-verification-code">邮箱验证码</label>
                        <input class="input auth-code-input" id="auth-verification-code" name="otp" inputmode="numeric" autocomplete="one-time-code" maxlength="12" placeholder="请输入邮件中的验证码">
                    </div>
                    <div class="auth-modal-meta">
                        <span>${isSignup ? '注册验证码仅用于当前邮箱' : '找回密码验证码仅用于当前邮箱'}</span>
                        <span>${canResend ? '现在可以重新发送' : `${countdown}s 后可重新发送`}</span>
                    </div>
                    <div class="${feedbackClass}" id="auth-verification-feedback">${escapeHtml(publicAuthFlow.feedback || '')}</div>
                </form>
            `,
            footer: `
                <button class="ghost-btn" data-action="cancel-auth-flow" type="button">返回修改邮箱</button>
                <button class="ghost-btn" data-action="resend-auth-otp" type="button" ${canResend ? '' : 'disabled'}>${canResend ? '重新发送' : `${countdown}s 后重发`}</button>
                <button class="solid-btn" data-action="submit-auth-verification" type="button">${isSignup ? '验证并继续' : '验证并下一步'}</button>
            `,
        };
    }

    function openAuthVerificationModal() {
        renderAuthVerificationModal();
        startAuthVerificationTimer();
        const inlinePanel = document.getElementById('auth-inline-verification');
        if (inlinePanel && !inlinePanel.hidden) {
            inlinePanel.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
        }
    }

    function closeAuthVerificationModal() {
        const modal = document.getElementById('auth-verification-modal');
        if (modal) {
            modal.classList.remove('open');
            modal.setAttribute('aria-hidden', 'true');
        }
        stopAuthVerificationTimer();
    }

    function renderAuthVerificationModal() {
        const inlinePanel = document.getElementById('auth-inline-verification');
        const modal = document.getElementById('auth-verification-modal');
        const title = document.getElementById('auth-verification-title');
        const copy = document.getElementById('auth-verification-copy');
        const body = document.getElementById('auth-verification-body');
        const footer = document.getElementById('auth-verification-footer');
        const view = buildAuthVerificationView();

        if (inlinePanel) {
            if (!view) {
                inlinePanel.hidden = true;
                inlinePanel.innerHTML = '';
            } else {
                inlinePanel.hidden = false;
                inlinePanel.innerHTML = `
                    <div class="auth-inline-verification-head">
                        <strong>${escapeHtml(view.title)}</strong>
                        <p>${escapeHtml(view.copy)}</p>
                    </div>
                    ${view.body}
                    <div class="auth-inline-verification-footer">${view.footer}</div>
                `;
            }
        }

        if (!modal || !title || !copy || !body || !footer) return;
        modal.classList.remove('open');
        modal.setAttribute('aria-hidden', 'true');
        if (!view) {
            body.innerHTML = '';
            footer.innerHTML = '';
            return;
        }
        title.textContent = view.title;
        copy.textContent = view.copy;
        body.innerHTML = '';
        footer.innerHTML = '';
    }

    async function cancelPublicAuthFlow() {
        const flowType = publicAuthFlow.flowType;
        clearPublicAuthFlow();
        closeAuthVerificationModal();
        if (flowType && realtimeState.client) {
            try {
                await realtimeState.client.auth.signOut();
            } catch (_) {
                // ignore
            }
        }
        authState.ui.feedback = '';
        authState.ui.feedbackType = '';
        authState.ui.mode = flowType === 'recovery' ? 'login' : 'register';
        persistAuthState();
        renderEntryState();
    }

    async function resendPublicAuthOtp() {
        if (!isRealtimeConfigured() || !hasPendingPublicAuthFlow()) return;
        if (getAuthResendCountdownSeconds() > 0) {
            renderAuthVerificationModal();
            return;
        }
        try {
            setPublicAuthFlowFeedback('正在重新发送验证码...');
            if (publicAuthFlow.flowType === 'signup') {
                const { error } = await withTimeout(
                    realtimeState.client.auth.resend({
                        type: 'signup',
                        email: publicAuthFlow.email,
                        options: {
                            emailRedirectTo: buildPublicAuthRedirect(),
                        },
                    }),
                    12000,
                    'signup_resend_timeout'
                );
                if (error) throw error;
            } else {
                const { error } = await withTimeout(
                    realtimeState.client.auth.resetPasswordForEmail(publicAuthFlow.email, {
                        redirectTo: buildPublicAuthRedirect(),
                    }),
                    12000,
                    'recovery_resend_timeout'
                );
                if (error) throw error;
            }
            publicAuthFlow.resendAvailableAt = Date.now() + AUTH_RESEND_COOLDOWN_MS;
            setPublicAuthFlowFeedback('验证码已重新发送，请去邮箱查收。', 'success');
            startAuthVerificationTimer();
        } catch (error) {
            setPublicAuthFlowFeedback(mapSupabaseAuthError(error));
        }
    }

    async function submitPublicVerificationCode() {
        if (!isRealtimeConfigured() || !hasPendingPublicAuthFlow()) return;
        const input = document.getElementById('auth-verification-code') || document.getElementById('auth-register-otp');
        const otp = String(input?.value || '').trim();
        if (!otp) {
            setPublicAuthFlowFeedback('请先填写邮箱验证码。');
            return;
        }
        try {
            publicAuthFlow.stage = publicAuthFlow.flowType === 'signup' ? 'verify-signup' : 'verify-recovery';
            setPublicAuthFlowFeedback('正在验证邮箱...');
            const { data, error } = await withTimeout(
                realtimeState.client.auth.verifyOtp({
                    email: publicAuthFlow.email,
                    token: otp,
                    type: publicAuthFlow.flowType === 'signup' ? 'signup' : 'recovery',
                }),
                12000,
                'verify_otp_timeout'
            );
            if (error) throw error;

            if (publicAuthFlow.flowType === 'signup') {
                const session = data?.session
                    || (await realtimeState.client.auth.getSession()).data?.session
                    || null;
                const profileSeed = {
                    displayName: publicAuthFlow.displayName,
                    roleTitle: publicAuthFlow.roleTitle,
                };
                clearPublicAuthFlow();
                closeAuthVerificationModal();
                authState.ui.feedback = '';
                authState.ui.feedbackType = '';
                persistAuthState();
                if (session?.user) {
                    await applyRealtimeSession(session, {
                        silent: true,
                        profileSeed,
                    });
                    showToast(`欢迎回来，${profileSeed.displayName || getRealtimeDisplayName()}`);
                } else {
                    authState.ui.mode = 'login';
                    authState.ui.feedback = '验证码校验成功，请使用刚才设置的密码登录。';
                    authState.ui.feedbackType = 'success';
                    persistAuthState();
                    renderEntryState();
                }
                return;
            }

            publicAuthFlow.stage = 'reset-password';
            publicAuthFlow.feedback = '';
            publicAuthFlow.feedbackType = '';
            persistPublicAuthFlow();
            renderEntryState();
            renderAuthVerificationModal();
        } catch (error) {
            if (publicAuthFlow.flowType === 'signup' || publicAuthFlow.flowType === 'recovery') {
                publicAuthFlow.stage = 'code';
            }
            setPublicAuthFlowFeedback(mapSupabaseAuthError(error));
        }
    }

    async function submitPublicPasswordReset() {
        if (!isRealtimeConfigured() || !isRecoveryPasswordStage()) return;
        const passwordInput = document.getElementById('auth-reset-password');
        const confirmInput = document.getElementById('auth-reset-password-confirm');
        const password = String(passwordInput?.value || '').trim();
        const confirmPassword = String(confirmInput?.value || '').trim();
        if (password.length < 6) {
            setPublicAuthFlowFeedback('新密码至少需要 6 位。');
            return;
        }
        if (password !== confirmPassword) {
            setPublicAuthFlowFeedback('两次输入的新密码不一致。');
            return;
        }
        try {
            setPublicAuthFlowFeedback('正在保存新密码...');
            const { error } = await withTimeout(
                realtimeState.client.auth.updateUser({ password }),
                12000,
                'reset_password_timeout'
            );
            if (error) throw error;
            const email = publicAuthFlow.email;
            clearPublicAuthFlow();
            closeAuthVerificationModal();
            try {
                await realtimeState.client.auth.signOut();
            } catch (_) {
                // ignore
            }
            authState.ui.mode = 'login';
            authState.ui.lastIdentifier = email;
            authState.ui.feedback = '新密码已保存，请用新密码重新登录。';
            authState.ui.feedbackType = 'success';
            persistAuthState();
            renderEntryState();
            showToast('密码重置成功，请重新登录');
        } catch (error) {
            setPublicAuthFlowFeedback(mapSupabaseAuthError(error));
        }
    }

    submitPublicVerificationCode = async function () {
        if (!isRealtimeConfigured() || !hasPendingPublicAuthFlow()) return;
        const input = document.getElementById('auth-verification-code') || document.getElementById('auth-register-otp');
        const otp = String(input?.value || '').trim();
        if (!otp) {
            setPublicAuthFlowFeedback('请先填写邮箱验证码。');
            return;
        }
        try {
            publicAuthFlow.stage = publicAuthFlow.flowType === 'signup' ? 'verify-signup' : 'verify-recovery';
            setPublicAuthFlowFeedback('正在验证邮箱...');
            const { error } = await withTimeout(
                realtimeState.client.auth.verifyOtp({
                    email: publicAuthFlow.email,
                    token: otp,
                    type: publicAuthFlow.flowType === 'signup' ? 'signup' : 'recovery',
                }),
                12000,
                'verify_otp_timeout'
            );
            if (error) throw error;

            if (publicAuthFlow.flowType === 'signup') {
                const email = publicAuthFlow.email;
                clearPublicAuthFlow();
                closeAuthVerificationModal();
                try {
                    await realtimeState.client.auth.signOut();
                } catch (_) {
                    // ignore
                }
                authState.ui.mode = 'login';
                authState.ui.lastIdentifier = email;
                authState.ui.feedback = '验证码校验成功，请回到登录页输入密码后再进入。';
                authState.ui.feedbackType = 'success';
                persistAuthState();
                renderEntryState();
                showToast('邮箱已验证，请重新登录进入');
                return;
            }

            publicAuthFlow.stage = 'reset-password';
            publicAuthFlow.feedback = '';
            publicAuthFlow.feedbackType = '';
            persistPublicAuthFlow();
            renderEntryState();
            renderAuthVerificationModal();
        } catch (error) {
            if (publicAuthFlow.flowType === 'signup' || publicAuthFlow.flowType === 'recovery') {
                publicAuthFlow.stage = 'code';
            }
            setPublicAuthFlowFeedback(mapSupabaseAuthError(error));
        }
    };

    async function deleteRealtimeAccount() {
        if (!isRealtimeConfigured() || !hasRealtimeSession()) return;
        const confirmed = window.confirm('确定删除当前公开账号吗？删除后会同时移除公开资料、会话成员和消息，且无法恢复。');
        if (!confirmed) return;
        try {
            const { error } = await withTimeout(
                realtimeState.client.rpc('delete_my_account'),
                12000,
                'delete_account_timeout'
            );
            if (error) throw error;
            clearPublicAuthFlow();
            clearRealtimeSessionState({ keepClient: true });
            authState.ui.mode = 'login';
            authState.ui.feedback = '当前公开账号已删除。';
            authState.ui.feedbackType = 'success';
            persistAuthState();
            renderAll();
            renderEntryState();
            showToast('公开账号已删除');
        } catch (error) {
            const message = String(error?.message || '');
            if (message.toLowerCase().includes('delete_my_account')) {
                authState.ui.feedback = '删除入口还没有同步到 Supabase，请重新执行最新的 schema.sql。';
                authState.ui.feedbackType = '';
                persistAuthState();
                renderEntryState();
                showToast('请先把最新 schema.sql 重新执行到 Supabase');
                return;
            }
            showToast(mapSupabaseAuthError(error));
        }
    }

    async function ensureRealtimeProfile(seed = {}) {
        if (!isRealtimeConfigured() || !hasRealtimeSession()) return null;
        const session = realtimeState.session;
        const displayName = String(
            seed.displayName
            || session.user.user_metadata?.display_name
            || state.profile.name
            || getRealtimeDisplayName(null, session)
        ).trim().slice(0, 48) || '在线用户';
        const roleTitle = String(
            seed.roleTitle
            || seed.role
            || session.user.user_metadata?.role_title
            || state.profile.title
            || '公开账号'
        ).trim().slice(0, 72) || '公开账号';
        const payload = {
            id: session.user.id,
            display_name: displayName,
            role_title: roleTitle,
            handle: buildPublicHandle(displayName, session.user.id),
        };
        const { error: upsertError } = await realtimeState.client
            .from('profiles')
            .upsert(payload, { onConflict: 'id' });
        if (upsertError) throw upsertError;
        const { data, error } = await realtimeState.client
            .from('profiles')
            .select('id, display_name, role_title, handle')
            .eq('id', session.user.id)
            .single();
        if (error) throw error;
        realtimeState.profile = data || payload;
        return realtimeState.profile;
    }

    async function hydrateRealtimeSessionData(options = {}) {
        try {
            await withTimeout(
                ensureRealtimeProfile(options.profileSeed || {}),
                10000,
                'profile_sync_timeout'
            );
            await withTimeout(
                loadRealtimeConversations({
                    preferredConversationId: realtimeState.selectedConversationId,
                    silent: true,
                }),
                10000,
                'conversation_sync_timeout'
            );
        } catch (error) {
            realtimeState.error = mapSupabaseAuthError(error);
            renderMessages();
            renderProfile();
        }
    }

    async function applyRealtimeSession(session, options = {}) {
        if (!session?.user) {
            clearRealtimeSessionState({ keepClient: true });
            if (!options.silent) {
                showToast('已退出公开账号');
            }
            renderAll();
            return;
        }
        authSession = cloneData(defaultAuthSession);
        persistAuthSession();
        realtimeState.session = session;
        authState.ui.feedback = '';
        authState.ui.feedbackType = '';
        authState.ui.lastIdentifier = String(session.user.email || authState.ui.lastIdentifier || '');
        persistAuthState();
        renderAll();
        void hydrateRealtimeSessionData(options);
    }

    async function initializeRealtimePlatform() {
        if (publicRuntime.loading || publicRuntime.checked || realtimeState.initializing) return;
        const preferLocalConfig = typeof window !== 'undefined'
            && (window.location.protocol === 'file:' || ['127.0.0.1', 'localhost'].includes(String(window.location.hostname || '').toLowerCase()));
        publicRuntime.loading = true;
        publicRuntime.error = '';
        realtimeState.initializing = true;
        syncAuthModeWithPublicFlow();
        renderEntryState();
        renderMessages();
        renderProfile();
        try {
            let payload;
            try {
                payload = await fetchJson(buildAppUrl(LOCAL_PUBLIC_CONFIG_ENDPOINT), {
                    headers: { Accept: 'application/json' },
                });
                if (!payload && !preferLocalConfig) {
                    throw new Error('local_public_config_unavailable');
                }
            } catch (localError) {
                payload = await fetchJson(buildAppUrl(PUBLIC_CONFIG_ENDPOINT), {
                    headers: { Accept: 'application/json' },
                });
            }
            publicRuntime.checked = true;
            publicRuntime.loading = false;
            publicRuntime.supabaseEnabled = Boolean(payload?.supabaseEnabled && payload?.supabaseUrl && payload?.supabaseAnonKey);
            publicRuntime.supabaseUrl = String(payload?.supabaseUrl || '');
            publicRuntime.supabaseAnonKey = String(payload?.supabaseAnonKey || '');
            publicRuntime.error = '';
            if (!publicRuntime.supabaseEnabled) {
                realtimeState.initializing = false;
                renderEntryState();
                renderMessages();
                renderProfile();
                return;
            }
            clearLegacyLocalAuthForPublicMode();
            clearPublicAuthFlow();
            const createClient = await loadSupabaseCreateClient();
            realtimeState.client = createClient(publicRuntime.supabaseUrl, publicRuntime.supabaseAnonKey, {
                auth: {
                    persistSession: true,
                    autoRefreshToken: true,
                    detectSessionInUrl: true,
                },
            });
            publicRuntime.libraryLoaded = true;
            const authListener = realtimeState.client.auth.onAuthStateChange((_event, session) => {
                window.setTimeout(() => {
                    if (session?.user && shouldHoldRealtimeSession()) {
                        renderEntryState();
                        renderAuthVerificationModal();
                        openAuthVerificationModal();
                        return;
                    }
                    void applyRealtimeSession(session, { silent: true });
                }, 0);
            });
            realtimeState.authSubscription = authListener?.data?.subscription
                || authListener?.subscription
                || null;
            let sessionResult;
            try {
                sessionResult = await withTimeout(
                    realtimeState.client.auth.getSession(),
                    6000,
                    'get_session_timeout'
                );
            } catch (sessionError) {
                if (String(sessionError?.message || '') !== 'get_session_timeout') {
                    throw sessionError;
                }
                sessionResult = { data: { session: null }, error: null };
            }
            const { data, error } = sessionResult;
            if (error) throw error;
            if (data?.session?.user) {
                if (shouldHoldRealtimeSession()) {
                    renderEntryState();
                    renderAuthVerificationModal();
                    openAuthVerificationModal();
                } else {
                    await applyRealtimeSession(data.session, { silent: true });
                }
            } else {
                renderEntryState();
                renderMessages();
                renderProfile();
            }
            if (hasPendingPublicAuthFlow()) {
                openAuthVerificationModal();
            }
        } catch (error) {
            publicRuntime.checked = true;
            publicRuntime.loading = false;
            publicRuntime.error = String(error?.message || 'public_config_unavailable');
            const canKeepPublicAuth = Boolean(publicRuntime.supabaseUrl && publicRuntime.supabaseAnonKey);
            publicRuntime.supabaseEnabled = canKeepPublicAuth;
            if (canKeepPublicAuth) {
                clearRealtimeSessionState({ keepClient: Boolean(realtimeState.client) });
            } else {
                publicRuntime.supabaseUrl = '';
                publicRuntime.supabaseAnonKey = '';
                clearRealtimeSessionState({ keepClient: false });
            }
            renderEntryState();
            renderMessages();
            renderProfile();
        } finally {
            realtimeState.initializing = false;
            publicRuntime.loading = false;
            if (hasPendingPublicAuthFlow()) {
                renderAuthVerificationModal();
            }
        }
    }

    const legacyLogout = logout;
    logout = async function () {
        if (hasRealtimeSession() && realtimeState.client) {
            try {
                await realtimeState.client.auth.signOut();
            } catch (error) {
                console.error(error);
            }
            clearRealtimeSessionState({ keepClient: true });
            authState.ui.mode = 'welcome';
            authState.ui.feedback = '';
            authState.ui.feedbackType = '';
            persistAuthState();
            renderAll();
            showToast('已退出公开账号');
            return;
        }
        legacyLogout();
    };

    const legacySubmitAuthForm = submitAuthForm;
    submitAuthForm = async function (event) {
        if (!publicRuntime.supabaseEnabled) {
            legacySubmitAuthForm(event);
            return;
        }
        event.preventDefault();
        authPending = true;
        if (!realtimeState.client) {
            authState.ui.feedback = '公开服务还没连上，请稍后再试。';
            authState.ui.feedbackType = '';
            persistAuthState();
            authPending = false;
            renderEntryState();
            return;
        }
        const form = new FormData(event.target);
        const mode = authState.ui.mode;
        const identifier = String(form.get('identifier') || '').trim();
        const password = String(form.get('password') || '').trim();
        const remember = form.get('remember') !== null;
        const hasPendingInlineVerification =
            (mode === 'register' && publicAuthFlow.flowType === 'signup' && hasPendingPublicAuthFlow())
            || (mode === 'reset-request' && publicAuthFlow.flowType === 'recovery' && hasPendingPublicAuthFlow());
        authSession.remember = Boolean(remember);
        persistAuthSession();
        authState.ui.lastIdentifier = identifier;
        authState.ui.feedback = mode === 'register' ? '正在创建账号...' : '正在登录...';
        authState.ui.feedbackType = '';
        persistAuthState();
        renderEntryState();
        if (!identifier || !password) {
            authState.ui.feedback = '请先填写邮箱和密码。';
            authState.ui.feedbackType = '';
            persistAuthState();
            authPending = false;
            renderEntryState();
            return;
        }
        if (!identifier.includes('@')) {
            authState.ui.feedback = '当前公开版先支持邮箱注册登录。';
            authState.ui.feedbackType = '';
            persistAuthState();
            authPending = false;
            renderEntryState();
            return;
        }
        try {
            if (mode === 'register') {
                const displayName = String(form.get('displayName') || '').trim();
                const role = String(form.get('role') || '').trim();
                if (!displayName) {
                    authState.ui.feedback = '注册时需要先填写昵称。';
                    authState.ui.feedbackType = '';
                    persistAuthState();
                    renderEntryState();
                    return;
                }
                if (password.length < 6) {
                    authState.ui.feedback = '密码至少需要 6 位。';
                    authState.ui.feedbackType = '';
                    persistAuthState();
                    renderEntryState();
                    return;
                }
                const { data, error } = await withTimeout(
                    realtimeState.client.auth.signUp({
                        email: identifier,
                        password,
                        options: {
                            data: {
                                display_name: displayName,
                                role_title: role || state.profile.title || '公开账号',
                            },
                            emailRedirectTo: buildPublicAuthRedirect(),
                        },
                    }),
                    12000,
                    'signup_timeout'
                );
                if (error) throw error;
                authState.ui.feedback = data?.session
                    ? '注册成功，已进入公开账号。'
                    : '注册成功，请先去邮箱确认，再回来登录。';
                authState.ui.feedbackType = 'success';
                persistAuthState();
                if (data?.session?.user) {
                    await applyRealtimeSession(data.session, {
                        silent: true,
                        profileSeed: {
                            displayName,
                            roleTitle: role,
                        },
                    });
                    showToast(`欢迎回来，${displayName}`);
                } else {
                    renderEntryState();
                }
                return;
            }

            const { data, error } = await withTimeout(
                realtimeState.client.auth.signInWithPassword({
                    email: identifier,
                    password,
                }),
                12000,
                'signin_timeout'
            );
            if (error) throw error;
            authState.ui.feedback = '';
            authState.ui.feedbackType = '';
            persistAuthState();
            await applyRealtimeSession(data.session, { silent: true });
            showToast(`欢迎回来，${getRealtimeDisplayName()}`);
        } catch (error) {
            if (mode === 'register' && publicAuthFlow.stage === 'signup-pending') {
                clearPublicAuthFlow();
            }
            authState.ui.feedback = mapSupabaseAuthError(error);
            authState.ui.feedbackType = '';
            persistAuthState();
            renderEntryState();
        } finally {
            authPending = false;
            renderEntryState();
        }
    };

    submitAuthForm = async function (event) {
        if (!publicRuntime.supabaseEnabled) {
            legacySubmitAuthForm(event);
            return;
        }
        event.preventDefault();
        authPending = true;
        clearPublicAuthFlow();
        if (!realtimeState.client) {
            authState.ui.feedback = '公开服务还没有连接成功，请稍后再试。';
            authState.ui.feedbackType = '';
            persistAuthState();
            authPending = false;
            renderEntryState();
            return;
        }

        const form = new FormData(event.target);
        const mode = authState.ui.mode;
        const identifier = String(form.get('identifier') || '').trim();
        const password = String(form.get('password') || '').trim();
        const remember = form.get('remember') !== null;
        authSession.remember = Boolean(remember);
        persistAuthSession();
        authState.ui.lastIdentifier = identifier;
        authState.ui.feedback = mode === 'register'
            ? '正在创建账号...'
            : mode === 'reset-request'
                ? '正在发送重置邮件...'
                : '正在登录...';
        authState.ui.feedbackType = '';
        persistAuthState();
        renderEntryState();

        if (!identifier) {
            authState.ui.feedback = '请先填写邮箱。';
            authState.ui.feedbackType = '';
            persistAuthState();
            authPending = false;
            renderEntryState();
            return;
        }

        if (!identifier.includes('@')) {
            authState.ui.feedback = '当前公开版先支持邮箱注册登录。';
            authState.ui.feedbackType = '';
            persistAuthState();
            authPending = false;
            renderEntryState();
            return;
        }

        try {
            if (mode === 'reset-request') {
                const { error } = await withTimeout(
                    realtimeState.client.auth.resetPasswordForEmail(identifier, {
                        redirectTo: buildPublicAuthRedirect(),
                    }),
                    12000,
                    'reset_request_timeout'
                );
                if (error) throw error;
                authState.ui.mode = 'login';
                authState.ui.feedback = `重置邮件已发送到 ${maskEmailAddress(identifier)}，请去邮箱点击链接完成重置后再回来登录。`;
                authState.ui.feedbackType = 'success';
                persistAuthState();
                renderEntryState();
                return;
            }

            if (!password) {
                authState.ui.feedback = '请先填写密码。';
                authState.ui.feedbackType = '';
                persistAuthState();
                renderEntryState();
                return;
            }

            if (mode === 'register') {
                const displayName = String(form.get('displayName') || '').trim();
                const roleTitle = String(form.get('role') || '').trim() || state.profile.title || '公开账号';
                if (!displayName) {
                    authState.ui.feedback = '注册时需要先填写昵称。';
                    authState.ui.feedbackType = '';
                    persistAuthState();
                    renderEntryState();
                    return;
                }
                if (password.length < 6) {
                    authState.ui.feedback = '密码至少需要 6 位。';
                    authState.ui.feedbackType = '';
                    persistAuthState();
                    renderEntryState();
                    return;
                }
                const { data, error } = await withTimeout(
                    realtimeState.client.auth.signUp({
                        email: identifier,
                        password,
                        options: {
                            data: {
                                display_name: displayName,
                                role_title: roleTitle,
                            },
                            emailRedirectTo: buildPublicAuthRedirect(),
                        },
                    }),
                    12000,
                    'signup_timeout'
                );
                if (error) throw error;
                if (data?.session?.user) {
                    try {
                        await realtimeState.client.auth.signOut();
                    } catch (_) {
                        // ignore
                    }
                }
                authState.ui.mode = 'login';
                authState.ui.feedback = `确认邮件已发送到 ${maskEmailAddress(identifier)}，请去邮箱点击确认链接，确认后再回来登录。`;
                authState.ui.feedbackType = 'success';
                persistAuthState();
                renderEntryState();
                return;
            }

            const { data, error } = await withTimeout(
                realtimeState.client.auth.signInWithPassword({
                    email: identifier,
                    password,
                }),
                12000,
                'signin_timeout'
            );
            if (error) throw error;
            authState.ui.feedback = '';
            authState.ui.feedbackType = '';
            persistAuthState();
            await applyRealtimeSession(data.session, { silent: true });
            showToast(`欢迎回来，${getRealtimeDisplayName()}`);
        } catch (error) {
            clearPublicAuthFlow();
            authState.ui.feedback = mapSupabaseAuthError(error);
            authState.ui.feedbackType = '';
            persistAuthState();
            renderEntryState();
        } finally {
            authPending = false;
            renderEntryState();
        }
    };

    // SECTION_AUTH
    async function loadRealtimeConversations(options = {}) {
        if (!isRealtimeConfigured() || !hasRealtimeSession()) return;
        realtimeState.conversationsLoading = true;
        if (!options.silent && state.ui.activePage === 'messages') {
            renderMessages();
        }
        const { data, error } = await realtimeState.client.rpc('list_my_direct_conversations');
        realtimeState.conversationsLoading = false;
        if (error) {
            realtimeState.error = mapSupabaseAuthError(error);
            renderMessages();
            return;
        }
        realtimeState.error = '';
        realtimeState.conversations = Array.isArray(data)
            ? data.map(normalizeRealtimeConversation).filter(Boolean)
            : [];
        const preferredId = options.preferredConversationId || realtimeState.selectedConversationId;
        const nextSelected = realtimeState.conversations.find((item) => item.id === preferredId)
            || realtimeState.conversations[0]
            || null;
        realtimeState.selectedConversationId = nextSelected?.id || null;
        if (nextSelected && options.skipMessageReload !== true) {
            await loadRealtimeMessages(nextSelected.id, { silent: options.silent });
            return;
        }
        if (!nextSelected) {
            await unsubscribeRealtimeChannel();
        }
        if (state.ui.activePage === 'messages') {
            renderMessages();
        }
    }

    async function subscribeRealtimeMessages(conversationId) {
        if (!isRealtimeConfigured() || !conversationId) return;
        if (realtimeState.subscribedConversationId === conversationId && realtimeState.messageChannel) return;
        await unsubscribeRealtimeChannel();
        const channel = realtimeState.client
            .channel(`renmai-conversation-${conversationId}`)
            .on(
                'postgres_changes',
                {
                    event: '*',
                    schema: 'public',
                    table: 'messages',
                    filter: `conversation_id=eq.${conversationId}`,
                },
                (payload) => {
                    const current = Array.isArray(realtimeState.messagesByConversation[conversationId])
                        ? [...realtimeState.messagesByConversation[conversationId]]
                        : [];
                    if (payload.eventType === 'INSERT' && payload.new) {
                        if (!current.some((item) => item.id === payload.new.id)) {
                            current.push(payload.new);
                        }
                    } else if (payload.eventType === 'UPDATE' && payload.new) {
                        const index = current.findIndex((item) => item.id === payload.new.id);
                        if (index >= 0) current[index] = payload.new;
                    } else if (payload.eventType === 'DELETE' && payload.old) {
                        realtimeState.messagesByConversation = {
                            ...realtimeState.messagesByConversation,
                            [conversationId]: current.filter((item) => item.id !== payload.old.id),
                        };
                        renderMessages();
                        return;
                    }
                    current.sort((a, b) => new Date(a.created_at).getTime() - new Date(b.created_at).getTime());
                    realtimeState.messagesByConversation = {
                        ...realtimeState.messagesByConversation,
                        [conversationId]: current,
                    };
                    void loadRealtimeConversations({
                        preferredConversationId: conversationId,
                        skipMessageReload: true,
                        silent: true,
                    });
                    renderMessages();
                }
            )
            .subscribe();
        realtimeState.messageChannel = channel;
        realtimeState.subscribedConversationId = conversationId;
    }

    async function loadRealtimeMessages(conversationId, options = {}) {
        if (!isRealtimeConfigured() || !conversationId) return;
        realtimeState.messageLoading = true;
        realtimeState.selectedConversationId = conversationId;
        if (!options.silent && state.ui.activePage === 'messages') {
            renderMessages();
        }
        const { data, error } = await realtimeState.client
            .from('messages')
            .select('id, conversation_id, sender_id, body, created_at')
            .eq('conversation_id', conversationId)
            .order('created_at', { ascending: true });
        realtimeState.messageLoading = false;
        if (error) {
            realtimeState.error = mapSupabaseAuthError(error);
            renderMessages();
            return;
        }
        realtimeState.error = '';
        realtimeState.messagesByConversation = {
            ...realtimeState.messagesByConversation,
            [conversationId]: Array.isArray(data) ? data : [],
        };
        await subscribeRealtimeMessages(conversationId);
        renderMessages();
    }

    function renderRealtimeConversationCard(item) {
        const active = getSelectedRealtimeConversation()?.id === item.id;
        const summary = item.lastMessagePreview || '还没有消息，先发一句问候吧。';
        return `
            <button class="thread-card ${active ? 'active' : ''}" data-action="select-realtime-conversation" data-id="${escapeAttribute(item.id)}" type="button">
                <div class="thread-head">
                    <div>
                        <strong>${escapeHtml(item.partnerDisplayName)}</strong>
                        <div class="analysis-summary">@${escapeHtml(item.partnerHandle || 'renmai-user')}</div>
                    </div>
                    <div class="badge">${escapeHtml(formatRealtimeTime(item.lastMessageAt))}</div>
                </div>
                <div class="thread-meta">
                    <span class="analysis-summary">${escapeHtml(item.partnerRoleTitle || '公开用户')}</span>
                    <span class="analysis-summary">仅会话成员可见</span>
                </div>
                <p class="thread-snippet">${escapeHtml(summary)}</p>
            </button>
        `;
    }

    function renderRealtimeDirectoryCard(item) {
        return `
            <button class="thread-card" data-action="start-realtime-conversation" data-id="${escapeAttribute(item.id)}" type="button">
                <div class="thread-head">
                    <div>
                        <strong>${escapeHtml(item.display_name || '未命名用户')}</strong>
                        <div class="analysis-summary">@${escapeHtml(item.handle || 'renmai-user')}</div>
                    </div>
                    <div class="badge">可发起对话</div>
                </div>
                <p class="thread-snippet">${escapeHtml(item.role_title || '公开用户')}</p>
            </button>
        `;
    }

    function getRealtimeMessageStream(conversationId) {
        const currentUserId = realtimeState.session?.user?.id;
        const conversation = realtimeState.conversations.find((item) => item.id === conversationId);
        return (realtimeState.messagesByConversation[conversationId] || []).map((item) => ({
            role: item.sender_id === currentUserId ? 'me' : 'other',
            text: String(item.body || ''),
            meta: `${item.sender_id === currentUserId ? '我' : (conversation?.partnerDisplayName || '对方')} · ${formatRealtimeTime(item.created_at)}`,
        }));
    }

    function renderRealtimeMessagesPanel() {
        const statusLabel = publicRuntime.loading
            ? '连接中'
            : publicRuntime.supabaseEnabled
                ? hasRealtimeSession()
                    ? '在线'
                    : '已配置'
                : '本地';
        const statusClass = publicRuntime.supabaseEnabled ? '' : 'warn';
        if (publicRuntime.loading) {
            return `
                <section class="panel panel-body" style="margin-bottom:18px;">
                    <div class="panel-header">
                        <div>
                            <h3 class="panel-title">真实对话</h3>
                            <p class="panel-subtitle">正在连接公开账号系统和实时聊天服务。</p>
                        </div>
                        <div class="badge ${statusClass}">${statusLabel}</div>
                    </div>
                    <div class="empty-state">请稍等，正在检查当前站点是否已经接通公开聊天。</div>
                </section>
            `;
        }
        if (!publicRuntime.supabaseEnabled) {
            return `
                <section class="panel panel-body" style="margin-bottom:18px;">
                    <div class="panel-header">
                        <div>
                            <h3 class="panel-title">真实对话</h3>
                            <p class="panel-subtitle">当前还没有配置 Supabase，所以现在仍然是本地演示模式。</p>
                        </div>
                        <div class="badge warn">${statusLabel}</div>
                    </div>
                    <div class="empty-state">把 PUBLIC_SUPABASE_URL 和 PUBLIC_SUPABASE_ANON_KEY 配好后，这里会自动切到真实用户登录和实时聊天。</div>
                </section>
            `;
        }
        if (!hasRealtimeSession()) {
            return `
                <section class="panel panel-body" style="margin-bottom:18px;">
                    <div class="panel-header">
                        <div>
                            <h3 class="panel-title">真实对话</h3>
                            <p class="panel-subtitle">公开访问已经接通。登录公开账号后，你就可以搜索其他用户并开始实时聊天。</p>
                        </div>
                        <div class="badge">${statusLabel}</div>
                    </div>
                    <div class="focus-list" style="margin-top:16px;">
                        <div class="focus-card">
                            <h4>隐私范围</h4>
                            <p>只展示公开昵称、handle 和角色说明，不显示邮箱、手机号和本地关系备注。</p>
                        </div>
                        <div class="focus-card">
                            <h4>聊天权限</h4>
                            <p>消息由会话成员权限控制，只有参与对话的人才能读取同一条消息流。</p>
                        </div>
                    </div>
                    <div class="detail-actions" style="margin-top:18px;">
                        <button class="solid-btn" data-action="switch-to-online-login" type="button">登录公开账号</button>
                    </div>
                </section>
            `;
        }
        const selected = getSelectedRealtimeConversation();
        const draft = selected ? getRealtimeDraft(selected.id) : '';
        const hasDraft = Boolean(draft.trim());
        const stream = selected ? getRealtimeMessageStream(selected.id) : [];
        const directoryHint = realtimeState.directoryQuery.length < 2
            ? '输入至少 2 个字搜索昵称或 handle。'
            : realtimeState.directoryLoading
                ? '正在搜索...'
                : realtimeState.directory.length
                    ? `找到 ${realtimeState.directory.length} 位可发起对话的用户。`
                    : '没有找到匹配用户。';
        const statusPill = `公开账号 · @${escapeHtml(getRealtimeHandle())}`;
        return `
            <section class="panel panel-body" style="margin-bottom:18px;">
                <div class="panel-header">
                    <div>
                        <h3 class="panel-title">真实对话</h3>
                        <p class="panel-subtitle">这一栏是公开访问后的真实聊天区，和下面的本地关系工作台分开保存。</p>
                    </div>
                    <div class="assistant-pill-row">
                        <div class="distance-pill">${statusPill}</div>
                        <div class="distance-pill">仅会话成员可见</div>
                    </div>
                </div>
                <form id="realtime-user-search-form" class="field-grid" style="margin-top:12px;">
                    <div class="field full">
                        <label for="realtime-user-search">搜索用户</label>
                        <div class="composer-bar">
                            <div class="composer-input-shell">
                                <input class="input" id="realtime-user-search" autocomplete="off" placeholder="按昵称或 handle 搜索" value="${escapeAttribute(realtimeState.directoryQuery)}">
                            </div>
                            <button class="solid-btn" type="submit">${realtimeState.directoryLoading ? '搜索中...' : '搜索'}</button>
                        </div>
                        <div class="profile-hint" style="margin-top:8px;">${escapeHtml(directoryHint)}</div>
                    </div>
                </form>
                ${realtimeState.error ? `<div class="empty-state" style="margin-top:14px;">${escapeHtml(realtimeState.error)}</div>` : ''}
                <div class="messages-layout" style="margin-top:18px;">
                    <div class="thread-list">
                        <div class="panel-header" style="padding:0 0 8px;">
                            <div>
                                <h4 class="panel-title" style="font-size:16px;">我的会话</h4>
                                <p class="panel-subtitle">真实用户的直接对话会出现在这里。</p>
                            </div>
                            <button class="ghost-btn" data-action="refresh-realtime-conversations" type="button">刷新</button>
                        </div>
                        ${realtimeState.conversationsLoading && !realtimeState.conversations.length
                            ? '<div class="empty-state">正在加载会话...</div>'
                            : (realtimeState.conversations.length
                                ? realtimeState.conversations.map(renderRealtimeConversationCard).join('')
                                : '<div class="empty-state">还没有真实会话。先搜索一个用户开始对话。</div>')}
                        <div class="panel-header" style="padding:12px 0 8px;">
                            <div>
                                <h4 class="panel-title" style="font-size:16px;">搜索结果</h4>
                                <p class="panel-subtitle">只显示公开档案字段。</p>
                            </div>
                        </div>
                        ${realtimeState.directory.length
                            ? realtimeState.directory.map(renderRealtimeDirectoryCard).join('')
                            : '<div class="empty-state">输入昵称或 handle 后开始搜索。</div>'}
                    </div>
                    <div class="message-shell">
                        ${selected ? `
                            <section class="conversation-card">
                                <div class="thread-head">
                                    <div>
                                        <h4 class="panel-title" style="font-size:18px;">${escapeHtml(selected.partnerDisplayName)}</h4>
                                        <p class="panel-subtitle">@${escapeHtml(selected.partnerHandle || 'renmai-user')} · ${escapeHtml(selected.partnerRoleTitle || '公开用户')}</p>
                                    </div>
                                    <div class="badge">${escapeHtml(formatRealtimeTime(selected.lastMessageAt))}</div>
                                </div>
                                <div class="conversation-stream">${realtimeState.messageLoading && !stream.length ? '<div class="empty-state">正在加载消息...</div>' : (stream.length ? stream.map(renderMessageBubble).join('') : '<div class="empty-state">从一句简单的问候开始吧。</div>')}</div>
                                <form id="realtime-message-form" class="message-composer">
                                    <div class="composer-bar">
                                        <div class="composer-input-shell">
                                            <textarea class="composer-textarea" id="realtime-composer" rows="1" placeholder="输入你想发给对方的话...">${escapeHtml(draft)}</textarea>
                                        </div>
                                        <button class="composer-send-btn ${hasDraft ? '' : 'disabled'}" type="submit">${realtimeState.sending ? '发送中...' : '发送'}</button>
                                    </div>
                                    <div class="composer-actions">
                                        <span class="composer-hint">Enter 发送，Shift+Enter 换行</span>
                                    </div>
                                </form>
                            </section>
                        ` : '<div class="empty-state">先从左侧会话列表里选一个人，或者搜索一个新用户开始聊天。</div>'}
                    </div>
                </div>
            </section>
        `;
    }

    const legacyRenderSessionChrome = renderSessionChrome;
    renderSessionChrome = function () {
        legacyRenderSessionChrome();
        const user = getCurrentUser();
        const sidebarMode = document.getElementById('sidebar-mode-pill');
        const topbarStatus = document.getElementById('topbar-status-pill');
        const avatar = document.getElementById('session-avatar');
        const name = document.getElementById('session-user-name');
        const role = document.getElementById('session-user-role');
        if (sidebarMode) {
            sidebarMode.textContent = user
                ? `${hasRealtimeSession() ? '公开账号' : '本地模式'} · ${user.name}`
                : publicRuntime.supabaseEnabled ? '公开站点已接通' : '静态 Web 初版';
        }
        if (topbarStatus) {
            topbarStatus.textContent = user
                ? (hasRealtimeSession() ? '已登录 · 实时聊天可用' : '本地会话 · 当前浏览器')
                : (publicRuntime.loading ? '正在连接公开服务' : publicRuntime.supabaseEnabled ? '公开访问已启用' : '本地演示模式');
        }
        if (avatar) avatar.textContent = getUserInitial(user?.name);
        if (name) name.textContent = user?.name || '演示访客';
        if (role) {
            role.textContent = hasRealtimeSession()
                ? `${user?.role || '公开账号'} · @${getRealtimeHandle()}`
                : user?.role || '本地体验账号';
        }
    };

    const legacyRenderEntryState = renderEntryState;
    renderEntryState = function () {
        legacyRenderEntryState();
        const mode = AUTH_MODES.includes(authState.ui.mode) ? authState.ui.mode : 'welcome';
        const authTitle = document.getElementById('auth-title');
        const authCopy = document.getElementById('auth-copy');
        const authSubmit = document.getElementById('auth-submit-btn');
        const authFootnote = document.getElementById('auth-footnote');
        if (authSubmit) {
            authSubmit.disabled = authPending;
        }
        if (hasRealtimeSession()) return;
        if (publicRuntime.loading) {
            if (authCopy) authCopy.textContent = '正在连接公开服务，马上就好。';
            if (authFootnote) authFootnote.textContent = '如果没有接通在线配置，会自动回到本地模式。';
            return;
        }
        if (!publicRuntime.supabaseEnabled) return;
        const hasPendingSignupVerification = mode === 'register'
            && publicAuthFlow.flowType === 'signup'
            && hasPendingPublicAuthFlow();
        const hasPendingRecoveryVerification = mode === 'reset-request'
            && publicAuthFlow.flowType === 'recovery'
            && hasPendingPublicAuthFlow();
        const showInlineVerification = hasPendingSignupVerification || hasPendingRecoveryVerification;

        if (mode === 'register') {
            if (authTitle) authTitle.textContent = '注册';
            if (authCopy) authCopy.textContent = '创建公开账号后，就能在网页端继续保存和查看你的关系工作台。';
            if (authSubmit) authSubmit.textContent = authPending ? '正在创建...' : '创建账号';
            if (authFootnote) authFootnote.textContent = '当前公开版先支持邮箱注册登录。';
        } else if (mode === 'login') {
            if (authTitle) authTitle.textContent = '登录';
            if (authCopy) authCopy.textContent = '登录公开账号，继续你的网页端关系工作台。';
            if (authSubmit) authSubmit.textContent = authPending ? '正在登录...' : '继续';
            if (authFootnote) authFootnote.textContent = '只公开昵称、handle 和角色说明，不显示邮箱。';
        } else {
            if (authTitle) authTitle.textContent = '欢迎';
            if (authCopy) authCopy.textContent = '这个版本可以公开访问，适合先看关系结果、再决定要不要切桌面版。';
            if (authFootnote) authFootnote.textContent = '你也可以先用体验账号看看网页版关系工作台。';
        }
    };

    const realtimeRenderEntryState = renderEntryState;
    renderEntryState = function () {
        realtimeRenderEntryState();

        const mode = AUTH_MODES.includes(authState.ui.mode) ? authState.ui.mode : 'welcome';
        const authForm = document.getElementById('auth-form');
        const authTitle = document.getElementById('auth-title');
        const authCopy = document.getElementById('auth-copy');
        const authSubmit = document.getElementById('auth-submit-btn');
        const authFootnote = document.getElementById('auth-footnote');
        const inlineVerification = document.getElementById('auth-inline-verification');
        const authNameField = document.getElementById('auth-name-field');
        const authPasswordField = document.getElementById('auth-password-field');
        const authPassword = document.getElementById('auth-password');
        const authRoleField = document.getElementById('auth-role-field');
        const authOtpField = document.getElementById('auth-otp-field');
        const authOtpHelp = document.getElementById('auth-otp-help');
        const authIdentifier = document.getElementById('auth-identifier');
        const authIdentifierLabel = authIdentifier?.closest('.field')?.querySelector('label');
        const rememberRow = document.getElementById('auth-remember-row');
        const forgotButton = document.getElementById('auth-forgot-btn');
        const altModeButton = document.getElementById('auth-alt-mode-btn');
        const welcomeTab = document.getElementById('auth-tab-welcome');
        const loginTab = document.getElementById('auth-tab-login');
        const registerTab = document.getElementById('auth-tab-register');

        if (publicRuntime.supabaseEnabled) {
            if (welcomeTab) welcomeTab.classList.toggle('active', mode === 'welcome');
            if (loginTab) loginTab.classList.toggle('active', mode === 'login' || mode === 'reset-request');
            if (registerTab) registerTab.classList.toggle('active', mode === 'register');
        }

        if (!publicRuntime.supabaseEnabled) {
            if (forgotButton) forgotButton.hidden = true;
            if (altModeButton) altModeButton.hidden = true;
            renderAuthVerificationModal();
            return;
        }

        if (publicAuthFlow.flowType) {
            clearPublicAuthFlow();
        }

        const showInlineVerification = false;

        if (authForm) authForm.hidden = mode === 'welcome';
        if (authNameField) authNameField.hidden = mode !== 'register';
        if (authRoleField) authRoleField.hidden = mode !== 'register';
        if (authOtpField) authOtpField.hidden = true;
        if (authOtpHelp) authOtpHelp.hidden = true;
        if (authPasswordField) authPasswordField.hidden = mode === 'reset-request';
        if (authPassword) authPassword.required = mode !== 'reset-request';
        if (rememberRow) rememberRow.hidden = mode === 'reset-request';
        if (forgotButton) forgotButton.hidden = mode !== 'login';

        if (authIdentifierLabel) {
            authIdentifierLabel.textContent = mode === 'reset-request' ? '邮箱' : '邮箱或手机号';
        }
        if (authIdentifier) {
            authIdentifier.placeholder = mode === 'reset-request' ? '例如：name@example.com' : '例如：demo@renmai.app';
        }

        if (altModeButton) {
            altModeButton.hidden = mode === 'welcome';
            if (mode === 'register') {
                altModeButton.textContent = '已有账号？去登录';
                altModeButton.dataset.mode = 'login';
            } else if (mode === 'reset-request') {
                altModeButton.textContent = '想起密码了，返回登录';
                altModeButton.dataset.mode = 'login';
            } else {
                altModeButton.textContent = '没有账号？去注册';
                altModeButton.dataset.mode = 'register';
            }
        }

        if (mode === 'register') {
            if (authTitle) authTitle.textContent = '注册';
            if (authCopy) authCopy.textContent = '创建公开账号后，我们会往你的邮箱发一封确认邮件。';
            if (authSubmit) authSubmit.textContent = authPending ? '正在创建...' : '创建账号';
            if (authFootnote) authFootnote.textContent = '去邮箱点击确认链接后，再回到登录页输入密码即可。';
        } else if (mode === 'reset-request') {
            if (authTitle) authTitle.textContent = '找回密码';
            if (authCopy) authCopy.textContent = '我们会往你的邮箱发送一封重置邮件。';
            if (authSubmit) authSubmit.textContent = authPending ? '正在发送...' : '发送重置邮件';
            if (authFootnote) authFootnote.textContent = '点击邮件里的重置链接后，再回来用新密码登录。';
        } else if (mode === 'login') {
            if (authTitle) authTitle.textContent = '登录';
            if (authCopy) authCopy.textContent = '登录公开账号，继续你的网页端关系工作台。';
            if (authSubmit) authSubmit.textContent = authPending ? '正在登录...' : '继续';
            if (authFootnote) authFootnote.textContent = '只公开昵称、handle 和角色说明，不显示邮箱。';
        }

        if (showInlineVerification) {
            const maskedEmail = maskEmailAddress(publicAuthFlow.email);
            if (authCopy) {
                authCopy.textContent = isRecoveryPasswordStage()
                    ? `邮箱 ${maskedEmail} 已验证，请直接在下方设置新密码。`
                    : `验证码已发送到 ${maskedEmail}，请直接在下方填写。`;
            }
            if (authSubmit) {
                authSubmit.textContent = isRecoveryPasswordStage() ? '请先完成新密码设置' : '请先完成验证码验证';
                authSubmit.disabled = true;
            }
            if (authFootnote) {
                authFootnote.textContent = '如果暂时没收到邮件，可以直接在下方重新发送，不需要重复注册。';
            }
        } else if (authSubmit) {
            authSubmit.disabled = authPending;
        }

        if (inlineVerification && !showInlineVerification) {
            inlineVerification.hidden = true;
        }

        renderAuthVerificationModal();
    };

    const legacyRenderMessages = renderMessages;
    renderMessages = function () {
        legacyRenderMessages();
        const host = document.getElementById('page-messages');
        if (!host) return;
        const localMarkup = host.innerHTML;
        host.innerHTML = `${renderRealtimeMessagesPanel()}${localMarkup}`;
        autoResizeRealtimeComposer();
        autoResizeMessageComposer();
    };

    const legacyRenderProfile = renderProfile;
    renderProfile = function () {
        legacyRenderProfile();
        const host = document.getElementById('page-profile');
        if (!host) return;
        const displaySettingsMarkup = typeof renderWebDisplaySettingsSection === 'function'
            ? renderWebDisplaySettingsSection().replace('<section class="panel panel-body">', '<section class="panel panel-body" style="margin-bottom:18px;">')
            : '';
        const runtimeLabel = publicRuntime.loading
            ? '连接中'
            : publicRuntime.supabaseEnabled
                ? hasRealtimeSession()
                    ? '已登录公开账号'
                    : '已配置，可登录'
                : '未配置';
        const profileMarkup = `
            <section class="panel panel-body settings-card" style="margin-bottom:18px;">
                <div class="panel-header">
                    <div>
                        <h3 class="panel-title">公开聊天状态</h3>
                        <p class="panel-subtitle">这一部分用于把当前站点切到真实用户和实时聊天模式。</p>
                    </div>
                    <div class="badge ${publicRuntime.supabaseEnabled ? '' : 'warn'}">${escapeHtml(runtimeLabel)}</div>
                </div>
                <div class="focus-list" style="margin-top:16px;">
                    <div class="focus-card">
                        <h4>当前身份</h4>
                        <p>${hasRealtimeSession() ? `${escapeHtml(getRealtimeDisplayName())} · @${escapeHtml(getRealtimeHandle())}` : '还没有登录公开账号'}</p>
                    </div>
                    <div class="focus-card">
                        <h4>公开字段</h4>
                        <p>只同步昵称、角色说明和 handle，不同步邮箱、手机号和本地关系备注。</p>
                    </div>
                    <div class="focus-card">
                        <h4>部署要求</h4>
                        <p>${publicRuntime.supabaseEnabled ? 'Cloudflare 已读取到 Supabase 公网配置。' : '需要先配置 PUBLIC_SUPABASE_URL 和 PUBLIC_SUPABASE_ANON_KEY。'}</p>
                    </div>
                </div>
            </section>
        `;
        host.innerHTML = `${displaySettingsMarkup}${profileMarkup}${host.innerHTML}`;
    };

    const realtimeProfileWithDelete = renderProfile;
    renderProfile = function () {
        realtimeProfileWithDelete();
        if (!publicRuntime.supabaseEnabled || !hasRealtimeSession()) return;
        const host = document.getElementById('page-profile');
        const card = host?.querySelector('.settings-card');
        if (!card || card.querySelector('.public-account-actions')) return;
        card.insertAdjacentHTML('beforeend', `
            <div class="detail-actions public-account-actions" style="margin-top:16px;">
                <button class="ghost-btn" data-action="delete-public-account" type="button" style="color: var(--danger); border-color: rgba(195, 83, 83, 0.22);">
                    删除当前公开账号
                </button>
            </div>
        `);
    };

    // SECTION_RENDER
    async function searchRealtimeUsers(query, options = {}) {
        if (!isRealtimeConfigured() || !hasRealtimeSession()) return;
        const normalized = sanitizeRealtimeSearch(query);
        realtimeState.directoryQuery = normalized;
        if (normalized.length < 2) {
            realtimeState.directory = [];
            realtimeState.directoryLoading = false;
            if (!options.silent && state.ui.activePage === 'messages') {
                renderMessages();
            }
            return;
        }
        realtimeState.directoryLoading = true;
        if (!options.silent && state.ui.activePage === 'messages') {
            renderMessages();
        }
        const { data, error } = await realtimeState.client
            .from('profiles')
            .select('id, display_name, role_title, handle')
            .neq('id', realtimeState.session.user.id)
            .or(`display_name.ilike.%${normalized}%,handle.ilike.%${normalized}%`)
            .limit(8);
        realtimeState.directoryLoading = false;
        if (error) {
            realtimeState.error = mapSupabaseAuthError(error);
            renderMessages();
            return;
        }
        realtimeState.error = '';
        realtimeState.directory = Array.isArray(data) ? data : [];
        renderMessages();
    }

    async function startRealtimeConversation(targetUserId) {
        if (!isRealtimeConfigured() || !hasRealtimeSession() || !targetUserId) return;
        const { data, error } = await realtimeState.client.rpc('start_direct_conversation', {
            target_user_id: targetUserId,
        });
        if (error) {
            realtimeState.error = mapSupabaseAuthError(error);
            renderMessages();
            return;
        }
        realtimeState.error = '';
        await loadRealtimeConversations({
            preferredConversationId: String(data || ''),
        });
        showToast('真实对话已经打开');
    }

    async function sendRealtimeMessage() {
        const selected = getSelectedRealtimeConversation();
        if (!selected || !hasRealtimeSession() || !isRealtimeConfigured()) return;
        const draft = getRealtimeDraft(selected.id).trim();
        if (!draft) {
            showToast('先输入你想发送的内容');
            return;
        }
        realtimeState.sending = true;
        renderMessages();
        const optimisticMessage = {
            id: `temp-${Date.now()}`,
            conversation_id: selected.id,
            sender_id: realtimeState.session.user.id,
            body: draft,
            created_at: new Date().toISOString(),
        };
        realtimeState.messagesByConversation = {
            ...realtimeState.messagesByConversation,
            [selected.id]: [...(realtimeState.messagesByConversation[selected.id] || []), optimisticMessage],
        };
        clearRealtimeDraft(selected.id);
        renderMessages();
        try {
            const { error } = await realtimeState.client
                .from('messages')
                .insert({
                    conversation_id: selected.id,
                    sender_id: realtimeState.session.user.id,
                    body: draft,
                });
            if (error) throw error;
            await loadRealtimeMessages(selected.id, { silent: true });
            await loadRealtimeConversations({
                preferredConversationId: selected.id,
                skipMessageReload: true,
                silent: true,
            });
        } catch (error) {
            realtimeState.error = mapSupabaseAuthError(error);
            realtimeState.messagesByConversation = {
                ...realtimeState.messagesByConversation,
                [selected.id]: (realtimeState.messagesByConversation[selected.id] || []).filter((item) => item.id !== optimisticMessage.id),
            };
            setRealtimeDraft(selected.id, draft);
            showToast('真实消息发送失败，请稍后再试');
        } finally {
            realtimeState.sending = false;
            renderMessages();
        }
    }

    // SECTION_ACTIONS

    document.addEventListener('click', async (event) => {
        const button = event.target.closest('[data-action]');
        if (!button) return;
        switch (button.dataset.action) {
            case 'submit-auth-form': {
                const form = document.getElementById('auth-form');
                if (form?.requestSubmit) {
                    form.requestSubmit();
                } else if (form) {
                    submitAuthForm({
                        preventDefault() {},
                        target: form,
                    });
                }
                break;
            }
            case 'open-reset-request':
                authState.ui.mode = 'reset-request';
                authState.ui.feedback = '';
                authState.ui.feedbackType = '';
                persistAuthState();
                renderEntryState();
                break;
            case 'switch-to-online-login':
                if (legacyHasActiveSession()) {
                    await logout();
                }
                setAuthMode('login');
                break;
            case 'close-auth-verification-modal':
            case 'cancel-auth-flow':
                await cancelPublicAuthFlow();
                break;
            case 'resend-auth-otp':
                await resendPublicAuthOtp();
                break;
            case 'submit-auth-verification':
                await submitPublicVerificationCode();
                break;
            case 'submit-auth-reset-password':
                await submitPublicPasswordReset();
                break;
            case 'delete-public-account':
                await deleteRealtimeAccount();
                break;
            case 'refresh-realtime-conversations':
                await loadRealtimeConversations();
                break;
            case 'select-realtime-conversation':
                await loadRealtimeMessages(button.dataset.id);
                break;
            case 'start-realtime-conversation':
                await startRealtimeConversation(button.dataset.id);
                break;
            default:
                break;
        }
    });

    document.addEventListener('input', (event) => {
        if (event.target.id === 'realtime-user-search') {
            realtimeState.directoryQuery = event.target.value;
        }
        if (event.target.id === 'realtime-composer') {
            const selected = getSelectedRealtimeConversation();
            if (!selected) return;
            setRealtimeDraft(selected.id, event.target.value);
            autoResizeRealtimeComposer();
        }
    });

    document.addEventListener('keydown', (event) => {
        if (event.target.id === 'realtime-composer' && event.key === 'Enter' && !event.shiftKey) {
            event.preventDefault();
            void sendRealtimeMessage();
        }
    });

    document.addEventListener('submit', (event) => {
        if (event.target.id === 'realtime-user-search-form') {
            event.preventDefault();
            void searchRealtimeUsers(realtimeState.directoryQuery);
        }
        if (event.target.id === 'realtime-message-form') {
            event.preventDefault();
            void sendRealtimeMessage();
        }
        if (event.target.id === 'auth-verification-form') {
            event.preventDefault();
            void submitPublicVerificationCode();
        }
        if (event.target.id === 'auth-reset-password-form') {
            event.preventDefault();
            void submitPublicPasswordReset();
        }
    });

    document.addEventListener('submit', (event) => {
        if (event.target.id === 'profile-form' && hasRealtimeSession()) {
            window.setTimeout(() => {
                void ensureRealtimeProfile({
                    displayName: state.profile.name,
                    roleTitle: state.profile.title,
                }).then(() => {
                    renderProfile();
                    renderMessages();
                }).catch((error) => {
                    console.error(error);
                });
            }, 0);
        }
    });

    document.getElementById('auth-verification-modal')?.addEventListener('click', (event) => {
        if (event.target.id === 'auth-verification-modal') {
            void cancelPublicAuthFlow();
        }
    });

    renderAll();
    void initializeRealtimePlatform();

    // SECTION_EVENTS
})();
