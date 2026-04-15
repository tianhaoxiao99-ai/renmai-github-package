const STORAGE_KEY = 'renmai-web-prototype-v3';
        const GEO_STORAGE_KEY = 'renmai-web-geo-cache-v1';
        const SECRET_STORAGE_KEY = 'renmai-web-secret-settings-v1';
        const AUTH_STORAGE_KEY = 'renmai-web-auth-v1';
        const AUTH_SESSION_KEY = 'renmai-web-auth-session-v1';
        const LOCAL_REGISTER_FLOW_KEY = 'renmai-local-register-flow-v1';
        const LOCAL_REGISTER_OTP_TTL_MS = 10 * 60 * 1000;
        const GEO_LOOKUP_INTERVAL = 1100;
        const API_HEALTH_ENDPOINT = '/api/health';
        const GEO_ENDPOINT = '/api/geo/geocode';
        const AI_CHAT_ENDPOINT = '/api/ai/chat';
        const AI_PORTRAIT_ENDPOINT = '/api/ai/portrait';
        const DEFAULT_AI_MODEL = '@cf/meta/llama-3.1-8b-instruct-fast';
        const DEFAULT_VISION_MODEL = '@cf/meta/llama-3.2-11b-vision-instruct';
        const PORTRAIT_MAX_DIMENSION = 1024;
        const PORTRAIT_MAX_BYTES = 1500000;
        const TARGET_PLACEHOLDER = '{{target}}';
        const PUBLIC_AUTH_FLOW_STORAGE_KEY = 'renmai-public-auth-flow-v1';
        const STANDALONE_STATIC_PREVIEW = (() => {
            if (typeof window === 'undefined' || !window.location) return false;
            const host = String(window.location.hostname || '').toLowerCase();
            return window.location.protocol === 'file:' || host === '127.0.0.1' || host === 'localhost';
        })();
        const AUTO_RESTORE_LOCAL_SESSION = false;
        const FRESH_START_REQUESTED = (() => {
            if (typeof window === 'undefined' || !window.location) return false;
            try {
                return new URLSearchParams(window.location.search).has('fresh');
            } catch (_) {
                return false;
            }
        })();
        const SESSION_RESUME_REQUESTED = (() => {
            if (typeof window === 'undefined' || !window.location) return false;
            try {
                const params = new URLSearchParams(window.location.search);
                return params.get('resume') === '1';
            } catch (_) {
                return false;
            }
        })();

        const PAGE_TITLES = {
            dashboard: '总览',
            relationships: '联系人',
            messages: '消息',
            analysis: '报告',
            gifts: '礼物',
            profile: '设置',
        };

        const PAGE_META = {
            dashboard: '网页版先看结果、补资料、导出数据；要直读微信本地库请用桌面版。',
            relationships: '这里适合补充重点联系人、标签和在线经营线索。',
            messages: '先看会话，再确认资料，最后再决定怎么继续回复。',
            analysis: '先看结论，再决定要不要切到桌面版深挖。',
            gifts: '按关系、场景和预算给出更稳妥的礼物范围。',
            profile: '网页端资料、主题和导出都在这里。',
        };

        const PAGE_SWITCH_HINTS = {
            dashboard: '正在整理首页：先看什么、点什么、网页版和桌面版差异。',
            relationships: '正在载入联系人...',
            messages: '正在恢复消息工作台...',
            analysis: '正在汇总报告...',
            gifts: '正在整理礼物建议...',
            profile: '正在加载设置...',
        };

        const AVAILABLE_PAGES = Object.keys(PAGE_TITLES);
        const JOURNEY_FLOW = ['dashboard', 'relationships', 'analysis', 'messages', 'gifts'];
        const RELATIONSHIP_RENDER_BATCH = 18;
        const ANALYSIS_RENDER_BATCH = 10;
        const MESSAGE_THREAD_RENDER_BATCH = 12;
        const JOURNEY_COPY = {
            dashboard: {
                title: '先看今天该处理谁',
                summary: '总览页先帮你确认重点对象、最近报告和接下来最值得做的一步。',
            },
            relationships: {
                title: '先搜人，再点开详情',
                summary: '联系人页先缩小范围，再看关系判断和建议节奏，不要直接跳过这一步。',
            },
            analysis: {
                title: '先看结论，再看依据',
                summary: '报告页会集中给出结论、风险点和下一步动作，AI 只是补写，不是主入口。',
            },
            messages: {
                title: '先选联系人，再开始回复',
                summary: '消息页更像整理台。先选线程，再补一句消息、上传人像或让 AI 帮你润色。',
            },
            gifts: {
                title: '先定对象，再选场景和预算',
                summary: '礼物页先看对象和理由，再调预算、收藏或带到报告，不要先盯价格。',
            },
        };
        const RELATION_BUDGET_BASES = {
            family: { min: 220, max: 680 },
            friend: { min: 150, max: 480 },
            colleague: { min: 120, max: 320 },
            classmate: { min: 100, max: 260 },
            partner: { min: 399, max: 1299 },
            mentor: { min: 180, max: 520 },
        };
        const TRAIT_LABELS = {
            practical: '实用',
            sentimental: '情绪价值',
            comfort: '关怀',
            formal: '正式感',
            novelty: '新鲜感',
            social: '共同体验',
        };
        const PORTRAIT_LABELS = {
            professional: '专业稳重',
            warm: '亲和自然',
            refined: '精致仪式',
            artistic: '文艺细腻',
            energetic: '活力社交',
            minimal: '简洁克制',
        };
        const ASSISTANT_INTENTS = ['问候', '跟进', '安慰', '邀约', '送礼沟通'];
        const AUTH_MODES = ['welcome', 'login', 'register', 'reset-request'];

        const RELATION_LABELS = {
            family: '家人',
            friend: '朋友',
            colleague: '同事',
            classmate: '同学',
            partner: '伴侣',
            mentor: '导师',
        };

        const IMPORTANCE_LABELS = {
            regular: '普通关注',
            important: '重要关系',
        };

        const WEB_THEME_PRESETS = {
            warm: {
                label: '暖杏',
                surface: 'rgba(255, 248, 241, 0.94)',
                surfaceSoft: 'rgba(255, 252, 248, 0.80)',
                border: 'rgba(203, 109, 75, 0.14)',
                accent: '#cb6d4b',
                accentSoft: 'rgba(203, 109, 75, 0.16)',
                text: '#2c2117',
                muted: 'rgba(44, 33, 23, 0.68)',
                background: 'radial-gradient(circle at top left, rgba(255, 228, 212, 0.75), transparent 42%), radial-gradient(circle at top right, rgba(255, 243, 228, 0.9), transparent 30%), linear-gradient(180deg, #fffaf6 0%, #fff5ee 100%)',
            },
            rose: {
                label: '淡红',
                surface: 'rgba(255, 247, 246, 0.94)',
                surfaceSoft: 'rgba(255, 251, 250, 0.82)',
                border: 'rgba(201, 106, 114, 0.16)',
                accent: '#c96a72',
                accentSoft: 'rgba(201, 106, 114, 0.16)',
                text: '#342322',
                muted: 'rgba(52, 35, 34, 0.68)',
                background: 'radial-gradient(circle at top left, rgba(255, 229, 231, 0.82), transparent 42%), radial-gradient(circle at top right, rgba(255, 244, 242, 0.92), transparent 34%), linear-gradient(180deg, #fff8f7 0%, #fbf1f0 100%)',
            },
            sakura: {
                label: '樱粉',
                surface: 'rgba(255, 247, 251, 0.94)',
                surfaceSoft: 'rgba(255, 251, 253, 0.82)',
                border: 'rgba(217, 140, 171, 0.16)',
                accent: '#d98cab',
                accentSoft: 'rgba(217, 140, 171, 0.16)',
                text: '#34242b',
                muted: 'rgba(52, 36, 43, 0.68)',
                background: 'radial-gradient(circle at top left, rgba(255, 233, 241, 0.8), transparent 42%), radial-gradient(circle at top right, rgba(255, 246, 250, 0.92), transparent 34%), linear-gradient(180deg, #fff8fb 0%, #fdf4f8 100%)',
            },
            macaron: {
                label: '马卡龙',
                surface: 'rgba(251, 252, 248, 0.94)',
                surfaceSoft: 'rgba(255, 253, 250, 0.82)',
                border: 'rgba(126, 182, 165, 0.16)',
                accent: '#7eb6a5',
                accentSoft: 'rgba(126, 182, 165, 0.16)',
                text: '#24302d',
                muted: 'rgba(36, 48, 45, 0.68)',
                background: 'radial-gradient(circle at top left, rgba(231, 245, 238, 0.82), transparent 42%), radial-gradient(circle at top right, rgba(255, 245, 247, 0.82), transparent 30%), linear-gradient(180deg, #fffdfa 0%, #f6f6f1 100%)',
            },
        };

        const WEB_DENSITY_LABELS = {
            comfortable: '舒展',
            compact: '紧凑',
        };

        const RELATION_BASE_INTIMACY = {
            family: 48,
            partner: 54,
            mentor: 42,
            friend: 38,
            colleague: 34,
            classmate: 30,
        };

        const RELATION_WEEKLY_TARGET = {
            family: 4,
            partner: 5,
            mentor: 1,
            friend: 2,
            colleague: 2,
            classmate: 1,
        };

        const RELATION_MONTHLY_TARGET = {
            family: 4,
            partner: 5,
            mentor: 2,
            friend: 2,
            colleague: 2,
            classmate: 1,
        };

        const GIFT_CATALOG = [
            { id: 'gift-headset', name: '降噪耳机', relationTypes: ['friend', 'partner', 'colleague'], occasion: ['生日', '纪念日'], price: 699, tone: '实用型', personaTags: ['practical', 'comfort', 'novelty'], reason: '高频使用、出错率低，适合关系较近且预算中高的对象。' },
            { id: 'gift-tea', name: '手作茶礼盒', relationTypes: ['family', 'mentor', 'colleague'], occasion: ['节日', '拜访'], price: 268, tone: '稳妥型', personaTags: ['formal', 'comfort', 'sentimental'], reason: '适合家人和长辈，也适合正式一些的拜访场景。' },
            { id: 'gift-flower', name: '永生花摆件', relationTypes: ['partner', 'friend'], occasion: ['纪念日', '生日'], price: 188, tone: '情绪价值', personaTags: ['sentimental', 'novelty'], reason: '仪式感强，适合需要表达心意的关系。' },
            { id: 'gift-massage', name: '便携按摩仪', relationTypes: ['family', 'partner'], occasion: ['节日', '生日'], price: 459, tone: '关怀型', personaTags: ['comfort', 'practical'], reason: '既表达关心也具有长期实用性，适合核心关系。' },
            { id: 'gift-book', name: '主题书单礼盒', relationTypes: ['mentor', 'friend', 'classmate'], occasion: ['生日', '拜访'], price: 149, tone: '内容型', personaTags: ['practical', 'formal', 'social'], reason: '适合有明确兴趣偏好的对象，也更容易做个性化表达。' },
            { id: 'gift-watch', name: '智能手表', relationTypes: ['partner', 'friend'], occasion: ['生日', '纪念日'], price: 1099, tone: '升级型', personaTags: ['practical', 'novelty', 'comfort'], reason: '适合重要关系升级阶段，兼顾仪式感和实用度。' },
            { id: 'gift-coffee', name: '咖啡器具套装', relationTypes: ['friend', 'colleague', 'classmate'], occasion: ['拜访', '生日'], price: 219, tone: '生活型', personaTags: ['social', 'novelty', 'practical'], reason: '轻松自然，不会太重，也适合共同兴趣场景。' },
            { id: 'gift-frame', name: '定制照片相框', relationTypes: ['family', 'partner', 'friend'], occasion: ['纪念日', '节日'], price: 129, tone: '纪念型', personaTags: ['sentimental', 'comfort'], reason: '适合有共同回忆的关系，成本不高但情绪价值强。' },
        ];

        const defaultAuthState = {
            users: [
                {
                    id: 'auth-demo-user',
                    name: '演示访客',
                    identifier: 'demo@renmai.app',
                    password: 'demo123456',
                    role: '网页体验账号',
                },
            ],
            ui: {
                mode: 'welcome',
                feedback: '',
                feedbackType: '',
                lastIdentifier: 'demo@renmai.app',
            },
        };

        const defaultAuthSession = {
            currentUserId: null,
            remember: true,
        };

        const defaultState = {
            profile: {
                name: '林知夏',
                title: '自由职业者 / 关系经营实践者',
                city: '杭州',
                phone: '13800138000',
                bio: '希望用更轻松的方式，把重要关系维护成长期资产。',
            },
            relationships: [
                { id: 'rel-1', name: '林然', type: 'friend', city: '上海', birthday: '04-08', weeklyFrequency: 4, monthlyDepth: 3, importanceTier: 'important', importanceRank: 3, lastContact: '2026-03-12', note: '最近在聊副业合作，适合约一次线下见面把合作边界聊清楚。', tags: ['大学同学', '合作中'] },
                { id: 'rel-2', name: '妈妈', type: 'family', city: '温州', birthday: '05-12', weeklyFrequency: 6, monthlyDepth: 5, importanceTier: 'important', importanceRank: 1, lastContact: '2026-03-14', note: '本周末准备回家，先确认一下家里需要我带什么。', tags: ['家人', '核心关系'] },
                { id: 'rel-3', name: '陈舟', type: 'colleague', city: '杭州', birthday: '09-02', weeklyFrequency: 2, monthlyDepth: 2, importanceTier: 'regular', importanceRank: 0, lastContact: '2026-03-06', note: '正在对接一个跨团队项目，建议下周主动跟进进度。', tags: ['项目协作'] },
                { id: 'rel-4', name: '苏禾', type: 'classmate', city: '南京', birthday: '03-27', weeklyFrequency: 0, monthlyDepth: 1, importanceTier: 'regular', importanceRank: 0, lastContact: '2026-02-24', note: '很久没见了，可以从近况和共同朋友切入重新联系。', tags: ['老同学', '待激活'] },
                { id: 'rel-5', name: '乔乔', type: 'partner', city: '杭州', birthday: '07-19', weeklyFrequency: 7, monthlyDepth: 6, importanceTier: 'important', importanceRank: 2, lastContact: '2026-03-15', note: '最近节奏都比较忙，下次约会可以提前把时间块锁住。', tags: ['亲密关系'] },
                { id: 'rel-6', name: '周老师', type: 'mentor', city: '北京', birthday: '11-04', weeklyFrequency: 1, monthlyDepth: 2, importanceTier: 'important', importanceRank: 4, lastContact: '2026-03-01', note: '上次给了很具体的建议，月底前适合做一次进度反馈。', tags: ['导师', '职业发展'] },
            ],
            analyses: [
                {
                    id: 'analysis-seed-1',
                    title: '本周关系热力扫描',
                    targetId: 'all',
                    score: 84,
                    summary: '你的核心关系整体稳定，但老同学和职场弱连接有轻微下滑，适合本周分两次做低打扰激活。',
                    insights: [
                        '妈妈和伴侣两条核心关系的互动节奏健康，可以继续保持。',
                        '苏禾已超过 18 天未联系，属于最适合重新激活的一条关系。',
                        '导师线最近有推进空间，适合做成果反馈而不是单纯问候。',
                    ],
                    suggestions: [
                        '先发 1 条近况消息给苏禾，把联系重新打开。',
                        '下周一上午主动和陈舟确认项目下一步，避免合作节奏断层。',
                        '月底前向周老师同步一次进展，提升反馈闭环。',
                    ],
                    createdAt: '2026-03-15',
                },
            ],
            assistantHistory: [
                {
                    id: 'assistant-seed-1',
                    targetId: 'rel-6',
                    intent: '跟进',
                    summary: '周老师这类导师关系，更适合“带着进度去反馈”，而不是空泛寒暄。',
                    reply: '周老师您好，上次您提到我应该先把节奏和边界梳理清楚，这两周我已经按这个思路推进了一版，也确实顺了很多。想跟您简单汇报一下目前的进度，如果您这周方便，我想再请您帮我看看下一步是否还有需要调整的地方。',
                    giftAdvice: '如果后续有线下拜访，建议控制在稳妥、不过分张扬的区间，偏内容型或茶礼更自然。',
                    budgetText: '当前更适合 ¥220 - ¥460 的稳妥型礼物。',
                    needs: ['重视尊重感和明确进展', '喜欢低打扰但具体的反馈'],
                    source: 'local',
                    createdAt: '2026-03-15',
                },
            ],
            manualMessages: [],
            messageDrafts: {},
            favorites: ['gift-tea', 'gift-flower'],
            settings: {
                weeklyDigest: true,
                birthdayReminder: true,
                privacyMode: false,
                aiProvider: 'cloudflare-workers-ai',
                aiModel: DEFAULT_AI_MODEL,
                webTheme: 'warm',
                webDensity: 'comfortable',
                webGuideDismissed: false,
                journeyGuideDismissed: false,
                relationshipGuideDismissed: false,
                analysisGuideDismissed: false,
                messageGuideDismissed: false,
                giftGuideDismissed: false,
            },
            bridge: {
                source: 'web-local',
                mode: 'web-local',
                importedAt: '',
                fileName: '',
                contactCount: 0,
                recordCount: 0,
                packageCount: 0,
                reportTitle: '',
                reportUsedAi: false,
            },
            ui: {
                activePage: 'dashboard',
                relationView: 'list',
                relationFilter: 'all',
                relationSearch: '',
                relationVisibleCount: RELATIONSHIP_RENDER_BATCH,
                selectedRelationshipId: 'rel-1',
                selectedMessageRelationshipId: 'rel-1',
                messageThreadVisibleCount: MESSAGE_THREAD_RENDER_BATCH,
                selectedAnalysisId: 'analysis-seed-1',
                analysisVisibleCount: ANALYSIS_RENDER_BATCH,
                selectedGiftRelationshipId: 'rel-1',
                giftRelation: 'friend',
                giftOccasion: '生日',
                giftBudget: 500,
                assistantTargetId: 'rel-1',
                assistantIntent: '问候',
                assistantScenario: '希望自然一些，不要太像模板话术。',
            },
        };
        const defaultSecretState = {
            cloudPortraitOptIn: false,
        };

        let state = loadState();
        let authState = loadAuthState();
        let authSession = loadAuthSession();
        let localRegisterFlow = loadLocalRegisterFlow();
        let secretState = loadSecretState();
        let geoCache = loadGeoCache();
        let toastTimer = null;
        let persistStateTimer = null;
        let relationshipRenderTimer = null;
        let giftRenderTimer = null;
        let pendingRelationshipSelection = null;
        let relationshipMap = null;
        let relationshipMapToken = 0;
        let mapRenderTimer = null;
        let pageTransitionFrame = null;
        let topbarMotionFrame = null;
        let aiPending = false;
        let appRevealTimer = null;
        let portraitReviewState = {
            candidate: null,
            pendingPage: null,
            analyzing: false,
        };
        let serviceHealth = createDefaultServiceHealth();

        function cloneData(value) {
            return typeof structuredClone === 'function'
                ? structuredClone(value)
                : JSON.parse(JSON.stringify(value));
        }

        function createDefaultServiceHealth() {
            return {
                loading: false,
                checked: false,
                error: '',
                aiAvailable: false,
                portraitAvailable: false,
                geoAvailable: false,
                textModel: DEFAULT_AI_MODEL,
                visionModel: DEFAULT_VISION_MODEL,
            };
        }

        function loadAuthState() {
            if (FRESH_START_REQUESTED) {
                try {
                    localStorage.removeItem(AUTH_STORAGE_KEY);
                    localStorage.removeItem(AUTH_SESSION_KEY);
                    sessionStorage.removeItem(AUTH_SESSION_KEY);
                    sessionStorage.removeItem(PUBLIC_AUTH_FLOW_STORAGE_KEY);
                    sessionStorage.removeItem(LOCAL_REGISTER_FLOW_KEY);
                    Object.keys(localStorage).forEach((key) => {
                        if (String(key).startsWith('sb-') && String(key).endsWith('-auth-token')) {
                            localStorage.removeItem(key);
                        }
                    });
                } catch (_) {
                    // ignore
                }
            }
            try {
                const raw = localStorage.getItem(AUTH_STORAGE_KEY);
                if (!raw) return cloneData(defaultAuthState);
                const parsed = JSON.parse(raw);
                const next = cloneData(defaultAuthState);
                if (Array.isArray(parsed.users)) next.users = parsed.users;
                if (parsed.ui) next.ui = { ...next.ui, ...parsed.ui };
                if (!AUTH_MODES.includes(next.ui.mode)) next.ui.mode = 'welcome';
                return next;
            } catch (_) {
                return cloneData(defaultAuthState);
            }
        }

        function loadAuthSession() {
            if (FRESH_START_REQUESTED) {
                return cloneData(defaultAuthSession);
            }
            if (!AUTO_RESTORE_LOCAL_SESSION && !SESSION_RESUME_REQUESTED) {
                return cloneData(defaultAuthSession);
            }
            const parseSession = (raw) => {
                if (!raw) return null;
                const parsed = JSON.parse(raw);
                return { ...defaultAuthSession, ...parsed };
            };
            try {
                const sessionRaw = sessionStorage.getItem(AUTH_SESSION_KEY);
                if (sessionRaw) return parseSession(sessionRaw);
            } catch (_) {
                // ignore
            }
            try {
                const localRaw = localStorage.getItem(AUTH_SESSION_KEY);
                if (localRaw) return parseSession(localRaw);
            } catch (_) {
                // ignore
            }
            return cloneData(defaultAuthSession);
        }

        function persistAuthState() {
            localStorage.setItem(AUTH_STORAGE_KEY, JSON.stringify({
                users: authState.users,
                ui: authState.ui,
            }));
        }

        function persistAuthSession() {
            const payload = JSON.stringify(authSession);
            try {
                sessionStorage.removeItem(AUTH_SESSION_KEY);
            } catch (_) {
                // ignore
            }
            localStorage.removeItem(AUTH_SESSION_KEY);
            if (!authSession.currentUserId) return;
            if (authSession.remember) {
                localStorage.setItem(AUTH_SESSION_KEY, payload);
                return;
            }
            try {
                sessionStorage.setItem(AUTH_SESSION_KEY, payload);
            } catch (_) {
                localStorage.setItem(AUTH_SESSION_KEY, payload);
            }
        }

        function sanitizeLocalRegisterFlow(raw) {
            if (!raw || typeof raw !== 'object') return null;
            const identifier = String(raw.identifier || '').trim();
            const displayName = String(raw.displayName || '').trim();
            const role = String(raw.role || '').trim();
            const password = String(raw.password || '').trim();
            const otp = String(raw.otp || '').trim();
            const expiresAt = Number(raw.expiresAt || 0);
            if (!identifier || !displayName || !password || !otp || !expiresAt) return null;
            return {
                identifier,
                normalizedIdentifier: identifier.toLowerCase(),
                displayName,
                role,
                password,
                remember: raw.remember !== false,
                otp,
                expiresAt,
            };
        }

        function loadLocalRegisterFlow() {
            try {
                const raw = sessionStorage.getItem(LOCAL_REGISTER_FLOW_KEY);
                if (!raw) return null;
                const parsed = sanitizeLocalRegisterFlow(JSON.parse(raw));
                if (!parsed || parsed.expiresAt <= Date.now()) {
                    sessionStorage.removeItem(LOCAL_REGISTER_FLOW_KEY);
                    return null;
                }
                return parsed;
            } catch (_) {
                return null;
            }
        }

        function persistLocalRegisterFlow() {
            try {
                if (!localRegisterFlow) {
                    sessionStorage.removeItem(LOCAL_REGISTER_FLOW_KEY);
                    return;
                }
                sessionStorage.setItem(LOCAL_REGISTER_FLOW_KEY, JSON.stringify(localRegisterFlow));
            } catch (_) {
                // ignore
            }
        }

        function clearLocalRegisterFlow() {
            localRegisterFlow = null;
            persistLocalRegisterFlow();
        }

        function maskIdentifier(value) {
            const text = String(value || '').trim();
            const at = text.indexOf('@');
            if (at > 1) {
                const left = text.slice(0, at);
                const right = text.slice(at);
                if (left.length <= 2) return `${left[0]}*${right}`;
                return `${left.slice(0, 2)}***${left.slice(-1)}${right}`;
            }
            if (text.length <= 6) return `${text.slice(0, 2)}***`;
            return `${text.slice(0, 3)}***${text.slice(-2)}`;
        }

        function renderLocalRegisterVerificationPanel(mode) {
            const panel = document.getElementById('auth-inline-verification');
            if (!panel) return;
            panel.hidden = true;
            panel.innerHTML = '';
            return;
            if (mode !== 'register') {
                panel.hidden = true;
                panel.innerHTML = '';
                return;
            }
            const now = Date.now();
            const activeFlow = localRegisterFlow && localRegisterFlow.expiresAt > now ? localRegisterFlow : null;
            if (!activeFlow) {
                panel.hidden = false;
                panel.innerHTML = `
                    <div class="auth-inline-verification-head">
                        <strong>邮箱验证码</strong>
                        <p>点击“创建并进入”后会先发送验证码，输入正确后才会创建成功。</p>
                    </div>
                    <div class="field">
                        <label for="auth-inline-otp">验证码</label>
                        <input class="input auth-code-input" id="auth-inline-otp" name="registerOtp" inputmode="numeric" autocomplete="one-time-code" maxlength="12" placeholder="先点创建获取验证码">
                    </div>
                `;
                return;
            }
            const seconds = Math.max(1, Math.ceil((activeFlow.expiresAt - now) / 1000));
            panel.hidden = false;
            panel.innerHTML = `
                <div class="auth-inline-verification-head">
                    <strong>验证码已发送到 ${escapeHtml(maskIdentifier(activeFlow.identifier))}</strong>
                    <p>请在 ${seconds} 秒内输入验证码，验证通过后才会创建并进入。</p>
                </div>
                <div class="field">
                    <label for="auth-inline-otp">验证码</label>
                    <input class="input auth-code-input" id="auth-inline-otp" name="registerOtp" inputmode="numeric" autocomplete="one-time-code" maxlength="12" placeholder="请输入邮箱验证码">
                </div>
            `;
        }

        if (FRESH_START_REQUESTED) {
            authState = cloneData(defaultAuthState);
            authSession = cloneData(defaultAuthSession);
            clearLocalRegisterFlow();
            authState.ui.mode = 'welcome';
            authState.ui.feedback = '';
            authState.ui.feedbackType = '';
            persistAuthState();
            persistAuthSession();
        }

        function getCurrentUser() {
            return authState.users.find((item) => item.id === authSession.currentUserId) || null;
        }

        function hasActiveSession() {
            return Boolean(getCurrentUser());
        }

        function loadState() {
            try {
                const raw = localStorage.getItem(STORAGE_KEY);
                if (!raw) return normalizeState(cloneData(defaultState));
                return normalizeState(JSON.parse(raw));
            } catch (_) {
                return normalizeState(cloneData(defaultState));
            }
        }

        function normalizeState(source) {
            const next = cloneData(defaultState);
            if (source && typeof source === 'object') {
                if (source.profile) next.profile = { ...next.profile, ...source.profile };
                if (Array.isArray(source.relationships)) next.relationships = source.relationships.map(normalizeRelationship);
                if (Array.isArray(source.analyses)) next.analyses = source.analyses;
                if (Array.isArray(source.assistantHistory)) next.assistantHistory = source.assistantHistory;
                if (Array.isArray(source.manualMessages)) next.manualMessages = source.manualMessages.map(normalizeManualMessage).filter(Boolean);
                if (source.messageDrafts && typeof source.messageDrafts === 'object') next.messageDrafts = { ...next.messageDrafts, ...source.messageDrafts };
                if (Array.isArray(source.favorites)) next.favorites = source.favorites;
                next.settings = normalizeSettings(source.settings || next.settings);
                next.bridge = normalizeBridge(source.bridge || next.bridge);
                if (source.ui) next.ui = { ...next.ui, ...source.ui };
            }
            next.settings = normalizeSettings(next.settings);
            next.bridge = normalizeBridge(next.bridge);
            next.relationships = next.relationships.map(normalizeRelationship);
            next.manualMessages = next.manualMessages.map(normalizeManualMessage).filter(Boolean);
            if (!AVAILABLE_PAGES.includes(next.ui.activePage)) {
                next.ui.activePage = 'dashboard';
            }
            if (!next.relationships.some((item) => item.id === next.ui.selectedGiftRelationshipId)) {
                next.ui.selectedGiftRelationshipId = next.relationships[0]?.id || null;
            }
            if (!next.relationships.some((item) => item.id === next.ui.selectedMessageRelationshipId)) {
                next.ui.selectedMessageRelationshipId = next.relationships[0]?.id || null;
            }
            if (!next.relationships.some((item) => item.id === next.ui.assistantTargetId)) {
                next.ui.assistantTargetId = next.relationships[0]?.id || null;
            }
            if (!ASSISTANT_INTENTS.includes(next.ui.assistantIntent)) {
                next.ui.assistantIntent = '问候';
            }
            return next;
        }

        function normalizeSettings(source = {}) {
            return {
                ...cloneData(defaultState.settings),
                ...source,
                weeklyDigest: source.weeklyDigest !== false,
                birthdayReminder: source.birthdayReminder !== false,
                privacyMode: Boolean(source.privacyMode),
                aiProvider: String(source.aiProvider || 'cloudflare-workers-ai'),
                aiModel: String(source.aiModel || DEFAULT_AI_MODEL),
                webTheme: sanitizeWebTheme(source.webTheme),
                webDensity: sanitizeWebDensity(source.webDensity),
                webGuideDismissed: Boolean(source.webGuideDismissed),
                journeyGuideDismissed: Boolean(source.journeyGuideDismissed),
                relationshipGuideDismissed: Boolean(source.relationshipGuideDismissed),
                analysisGuideDismissed: Boolean(source.analysisGuideDismissed),
                messageGuideDismissed: Boolean(source.messageGuideDismissed),
                giftGuideDismissed: Boolean(source.giftGuideDismissed),
            };
        }

        function normalizeBridge(source = {}) {
            return {
                ...cloneData(defaultState.bridge),
                ...source,
                source: String(source.source || 'web-local'),
                mode: String(source.mode || 'web-local'),
                importedAt: String(source.importedAt || ''),
                fileName: String(source.fileName || ''),
                contactCount: Number(source.contactCount || 0),
                recordCount: Number(source.recordCount || 0),
                packageCount: Number(source.packageCount || 0),
                reportTitle: String(source.reportTitle || ''),
                reportUsedAi: Boolean(source.reportUsedAi),
            };
        }

        function normalizeManualMessage(item) {
            if (!item || typeof item !== 'object') return null;
            const relationshipId = String(item.relationshipId || '').trim();
            const text = String(item.text || '').trim();
            if (!relationshipId || !text) return null;
            const role = item.role === 'other' ? 'other' : 'me';
            return {
                id: String(item.id || `manual-${Date.now()}`),
                relationshipId,
                role,
                text: text.slice(0, 1200),
                meta: String(item.meta || '').trim().slice(0, 120),
                createdAt: String(item.createdAt || formatDate(new Date())),
            };
        }

        function flushPersistState() {
            if (persistStateTimer) {
                clearTimeout(persistStateTimer);
                persistStateTimer = null;
            }
            localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
        }

        function persistState(immediate = false) {
            if (immediate) {
                flushPersistState();
                return;
            }
            if (persistStateTimer) {
                clearTimeout(persistStateTimer);
            }
            persistStateTimer = setTimeout(() => {
                persistStateTimer = null;
                localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
            }, 140);
        }

        function scheduleRelationshipRender(selectionStart = null, selectionEnd = selectionStart) {
            pendingRelationshipSelection = Number.isInteger(selectionStart)
                ? {
                    start: selectionStart,
                    end: Number.isInteger(selectionEnd) ? selectionEnd : selectionStart,
                }
                : null;
            if (relationshipRenderTimer) {
                clearTimeout(relationshipRenderTimer);
            }
            relationshipRenderTimer = setTimeout(() => {
                relationshipRenderTimer = null;
                if (state.ui.activePage !== 'relationships') {
                    pendingRelationshipSelection = null;
                    return;
                }
                renderRelationships();
                const selection = pendingRelationshipSelection;
                pendingRelationshipSelection = null;
                if (!selection) return;
                requestAnimationFrame(() => {
                    const input = document.getElementById('relationship-search');
                    if (!input) return;
                    const start = Math.min(selection.start, input.value.length);
                    const end = Math.min(selection.end, input.value.length);
                    input.focus();
                    input.setSelectionRange(start, end);
                });
            }, 70);
        }

        function scheduleGiftRender() {
            if (giftRenderTimer) {
                clearTimeout(giftRenderTimer);
            }
            giftRenderTimer = setTimeout(() => {
                giftRenderTimer = null;
                if (state.ui.activePage === 'gifts') {
                    renderGifts();
                }
            }, 56);
        }

        function sanitizeWebTheme(value) {
            const normalized = String(value || '').trim();
            if (normalized === 'sage') return 'macaron';
            return WEB_THEME_PRESETS[normalized] ? normalized : 'warm';
        }

        function sanitizeWebDensity(value) {
            return String(value || '').trim() === 'compact' ? 'compact' : 'comfortable';
        }

        function getWebThemePreset() {
            return WEB_THEME_PRESETS[sanitizeWebTheme(state.settings.webTheme)] || WEB_THEME_PRESETS.warm;
        }

        function getWebDensityLabel() {
            return WEB_DENSITY_LABELS[sanitizeWebDensity(state.settings.webDensity)] || WEB_DENSITY_LABELS.comfortable;
        }

        function injectWebExperienceStyles() {
            if (document.getElementById('renmai-web-experience-styles')) return;
            const style = document.createElement('style');
            style.id = 'renmai-web-experience-styles';
            const themeBackgroundMarkup = Object.entries(WEB_THEME_PRESETS)
                .map(([key, preset]) => `
                body[data-web-theme="${key}"] {
                    background: ${preset.background};
                    color: ${preset.text};
                }`)
                .join('');
            style.textContent = `
                ${themeBackgroundMarkup}
                body[data-web-theme] .page,
                body[data-web-theme] .page-title,
                body[data-web-theme] .panel,
                body[data-web-theme] .hero-card,
                body[data-web-theme] .metric-card,
                body[data-web-theme] .quick-card,
                body[data-web-theme] .relationship-card,
                body[data-web-theme] .report-card,
                body[data-web-theme] .focus-card,
                body[data-web-theme] .settings-card,
                body[data-web-theme] .conversation-card,
                body[data-web-theme] .portrait-workbench,
                body[data-web-theme] .thread-card,
                body[data-web-theme] .gift-card,
                body[data-web-theme] .analysis-card,
                body[data-web-theme] .sidebar,
                body[data-web-theme] .topbar,
                body[data-web-theme] .sidebar-card,
                body[data-web-theme] .workspace-brief,
                body[data-web-theme] .workspace-brief-card,
                body[data-web-theme] .dashboard-pulse-card,
                body[data-web-theme] .dashboard-radar-summary,
                body[data-web-theme] .dashboard-insight-item {
                    transition: background-color 180ms ease, border-color 180ms ease, box-shadow 180ms ease, transform 180ms ease;
                }
                body[data-web-theme] .panel,
                body[data-web-theme] .hero-card,
                body[data-web-theme] .metric-card,
                body[data-web-theme] .quick-card,
                body[data-web-theme] .relationship-card,
                body[data-web-theme] .report-card,
                body[data-web-theme] .focus-card,
                body[data-web-theme] .settings-card,
                body[data-web-theme] .conversation-card,
                body[data-web-theme] .portrait-workbench,
                body[data-web-theme] .thread-card,
                body[data-web-theme] .gift-card,
                body[data-web-theme] .analysis-card,
                body[data-web-theme] .sidebar-card,
                body[data-web-theme] .workspace-brief,
                body[data-web-theme] .workspace-brief-card,
                body[data-web-theme] .dashboard-pulse-card,
                body[data-web-theme] .dashboard-radar-summary,
                body[data-web-theme] .dashboard-insight-item {
                    border-color: var(--renmai-web-border, rgba(203, 109, 75, 0.14));
                    box-shadow: 0 16px 40px rgba(60, 38, 26, 0.08);
                }
                body[data-web-theme] .sidebar,
                body[data-web-theme] .topbar {
                    border-color: var(--renmai-web-border, rgba(203, 109, 75, 0.14));
                    background: color-mix(in srgb, var(--renmai-web-surface, rgba(255, 248, 241, 0.9)) 86%, white 14%);
                }
                body[data-web-theme] .brand-mark {
                    background: linear-gradient(135deg, var(--renmai-web-accent-soft, rgba(203, 109, 75, 0.16)), rgba(255, 255, 255, 0.68));
                    color: var(--renmai-web-accent, #cb6d4b);
                    box-shadow: inset 0 0 0 1px var(--renmai-web-border, rgba(203, 109, 75, 0.14));
                }
                body[data-web-theme] .nav-item.active {
                    background: linear-gradient(135deg, var(--renmai-web-accent-soft, rgba(203, 109, 75, 0.14)), rgba(255, 255, 255, 0.58));
                    box-shadow: inset 0 0 0 1px color-mix(in srgb, var(--renmai-web-border, rgba(203, 109, 75, 0.14)) 80%, white 20%);
                }
                body[data-web-theme] .mode-pill,
                body[data-web-theme] .badge,
                body[data-web-theme] .status-pill,
                body[data-web-theme] .session-chip,
                body[data-web-theme] .chip-btn,
                body[data-web-theme] .ghost-btn,
                body[data-web-theme] .solid-btn {
                    border-color: var(--renmai-web-border, rgba(203, 109, 75, 0.14));
                }
                body[data-web-theme] .solid-btn,
                body[data-web-theme] .badge,
                body[data-web-theme] .mode-pill.active,
                body[data-web-theme] .chip-btn.active,
                body[data-web-theme] .web-toggle.active {
                    background: var(--renmai-web-accent-soft, rgba(203, 109, 75, 0.16));
                    color: var(--renmai-web-accent, #cb6d4b);
                }
                body[data-web-theme] .web-toggle,
                body[data-web-theme] .guide-card {
                    border: 1px solid var(--renmai-web-border, rgba(203, 109, 75, 0.14));
                    background: var(--renmai-web-surface-soft, rgba(255, 252, 248, 0.8));
                    border-radius: 18px;
                }
                body[data-web-theme] .web-guide-grid,
                body[data-web-theme] .web-diff-grid {
                    display: grid;
                    gap: 12px;
                    margin-top: 16px;
                }
                body[data-web-theme] .web-guide-grid {
                    grid-template-columns: repeat(3, minmax(0, 1fr));
                }
                body[data-web-theme] .web-diff-grid {
                    grid-template-columns: repeat(2, minmax(0, 1fr));
                }
                body[data-web-theme] .guide-card {
                    padding: 18px;
                    min-height: 150px;
                    display: flex;
                    flex-direction: column;
                    gap: 10px;
                }
                body[data-web-theme] .guide-step {
                    width: 30px;
                    height: 30px;
                    display: inline-flex;
                    align-items: center;
                    justify-content: center;
                    border-radius: 999px;
                    background: var(--renmai-web-accent-soft, rgba(203, 109, 75, 0.16));
                    color: var(--renmai-web-accent, #cb6d4b);
                    font-weight: 700;
                }
                body[data-web-theme] .web-diff-item {
                    padding: 16px;
                    border: 1px solid var(--renmai-web-border, rgba(203, 109, 75, 0.14));
                    border-radius: 16px;
                    background: var(--renmai-web-surface-soft, rgba(255, 252, 248, 0.8));
                }
                body[data-web-theme] .web-setting-block {
                    display: flex;
                    flex-direction: column;
                    gap: 6px;
                    margin-top: 14px;
                }
                body[data-web-theme] .web-toggle-label {
                    font-size: 12px;
                    letter-spacing: 0.08em;
                    text-transform: uppercase;
                    color: var(--renmai-web-muted, rgba(44, 33, 23, 0.68));
                }
                body[data-web-theme] .web-toggle-row {
                    display: flex;
                    flex-wrap: wrap;
                    gap: 10px;
                }
                body[data-web-theme] .web-toggle {
                    padding: 10px 14px;
                    cursor: pointer;
                }
                @media (max-width: 960px) {
                    body[data-web-theme] .web-guide-grid,
                    body[data-web-theme] .web-diff-grid,
                    body[data-web-density="compact"] .web-guide-grid,
                    body[data-web-density="compact"] .web-diff-grid {
                        grid-template-columns: 1fr;
                    }
                }
                body[data-web-density="compact"] .page-stack,
                body[data-web-density="compact"] .section-grid {
                    gap: 16px;
                }
                body[data-web-density="compact"] .panel,
                body[data-web-density="compact"] .hero-card,
                body[data-web-density="compact"] .metric-card,
                body[data-web-density="compact"] .quick-card,
                body[data-web-density="compact"] .relationship-card,
                body[data-web-density="compact"] .report-card,
                body[data-web-density="compact"] .focus-card,
                body[data-web-density="compact"] .settings-card,
                body[data-web-density="compact"] .conversation-card,
                body[data-web-density="compact"] .portrait-workbench,
                body[data-web-density="compact"] .thread-card,
                body[data-web-density="compact"] .gift-card,
                body[data-web-density="compact"] .analysis-card {
                    padding-top: 14px !important;
                    padding-bottom: 14px !important;
                }
                body[data-web-density="compact"] .hero-title {
                    font-size: clamp(28px, 4.5vw, 40px);
                }
                body[data-web-density="compact"] .hero-copy,
                body[data-web-density="compact"] .panel-subtitle,
                body[data-web-density="compact"] .analysis-summary {
                    line-height: 1.55;
                }
                body[data-web-density="compact"] .guide-card {
                    padding: 16px;
                }
                body[data-web-density="compact"] .web-guide-grid,
                body[data-web-density="compact"] .web-diff-grid {
                    gap: 10px;
                    margin-top: 12px;
                }
                body[data-web-density="compact"] .web-guide-grid {
                    grid-template-columns: repeat(3, minmax(0, 1fr));
                }
                body[data-web-density="compact"] .web-diff-grid {
                    grid-template-columns: repeat(2, minmax(0, 1fr));
                }
                body[data-web-density="compact"] .web-toggle-row {
                    gap: 8px;
                }
                body[data-web-density="compact"] .web-toggle {
                    padding: 8px 12px;
                }
            `;
            document.head.appendChild(style);
        }

        function applyWebExperiencePreferences() {
            if (typeof document === 'undefined' || !document.body) return;
            injectWebExperienceStyles();
            const themeKey = sanitizeWebTheme(state.settings.webTheme);
            const densityKey = sanitizeWebDensity(state.settings.webDensity);
            const theme = WEB_THEME_PRESETS[themeKey] || WEB_THEME_PRESETS.warm;
            document.body.dataset.webTheme = themeKey;
            document.body.dataset.webDensity = densityKey;
            document.body.style.setProperty('--renmai-web-surface', theme.surface);
            document.body.style.setProperty('--renmai-web-surface-soft', theme.surfaceSoft);
            document.body.style.setProperty('--renmai-web-border', theme.border);
            document.body.style.setProperty('--renmai-web-accent', theme.accent);
            document.body.style.setProperty('--renmai-web-accent-soft', theme.accentSoft);
            document.body.style.setProperty('--renmai-web-text', theme.text);
            document.body.style.setProperty('--renmai-web-muted', theme.muted);
            document.querySelectorAll('[data-action="set-web-theme"][data-theme]').forEach((button) => {
                button.classList.toggle('active', button.dataset.theme === themeKey);
            });
            document.querySelectorAll('[data-action="set-web-density"][data-density]').forEach((button) => {
                button.classList.toggle('active', button.dataset.density === densityKey);
            });
        }

        function setWebTheme(nextTheme) {
            state.settings.webTheme = sanitizeWebTheme(nextTheme);
            persistState();
            applyWebExperiencePreferences();
            renderActivePage();
            showToast(`已切换为 ${getWebThemePreset().label} 主题`);
        }

        function setWebDensity(nextDensity) {
            state.settings.webDensity = sanitizeWebDensity(nextDensity);
            persistState();
            applyWebExperiencePreferences();
            renderActivePage();
            showToast(`已切换为 ${getWebDensityLabel()} 密度`);
        }

        function dismissWebGuide() {
            state.settings.webGuideDismissed = true;
            persistState();
            renderDashboard();
            showToast('已隐藏新手引导');
        }

        function reopenWebGuide() {
            state.settings.webGuideDismissed = false;
            persistState();
            renderDashboard();
            showToast('已重新显示新手引导');
        }

        function dismissJourneyGuide() {
            state.settings.journeyGuideDismissed = true;
            persistState();
            renderActivePage();
            showToast('已隐藏首次使用路径');
        }

        function reopenJourneyGuide() {
            state.settings.journeyGuideDismissed = false;
            persistState();
            renderActivePage();
            showToast('已重新显示首次使用路径');
        }

        function renderJourneyReopenButton() {
            if (!state.settings.journeyGuideDismissed) return '';
            return '<button class="chip-btn" data-action="reopen-journey-guide" type="button">重新看首次路径</button>';
        }

        function getPageGuideSettingKey(page) {
            if (page === 'relationships') return 'relationshipGuideDismissed';
            if (page === 'analysis') return 'analysisGuideDismissed';
            if (page === 'messages') return 'messageGuideDismissed';
            if (page === 'gifts') return 'giftGuideDismissed';
            return '';
        }

        function isPageGuideDismissed(page) {
            const key = getPageGuideSettingKey(page);
            return key ? Boolean(state.settings[key]) : false;
        }

        function setPageGuideDismissed(page, dismissed) {
            const key = getPageGuideSettingKey(page);
            if (!key) return;
            state.settings[key] = Boolean(dismissed);
            persistState();
            renderActivePage();
            showToast(dismissed ? '已隐藏当前页教程' : '已重新显示当前页教程');
        }

        function dismissPageGuide(page) {
            setPageGuideDismissed(page, true);
        }

        function reopenPageGuide(page) {
            setPageGuideDismissed(page, false);
        }

        function renderPageGuideSection(page) {
            if (isPageGuideDismissed(page)) return '';
            const configMap = {
                relationships: {
                    title: '联系人页先找人，再看理由',
                    subtitle: '这一页不是最终报告页。先缩小范围，再点开对象，看关系判断、维护建议和现实成本。',
                    note: '如果你想知道今天先联系谁，先在这里找人；如果你想看整体结论和排序，再切到“分析”页。',
                    steps: [
                        {
                            title: '先搜人',
                            body: '先用上面的搜索框搜姓名、备注、标签或城市，把列表缩到你真正想看的对象。',
                            meta: '对应控件：搜索框',
                        },
                        {
                            title: '再点联系人卡片',
                            body: '左侧卡片是入口。点开后右侧会显示关系判断、最近提醒和下一步建议。',
                            meta: '对应控件：联系人卡片',
                        },
                        {
                            title: '距离图只看现实成本',
                            body: '如果你要安排见面或估算维护成本，再切到“距离图”；它不代表关系强弱。',
                            meta: '对应控件：列表 / 距离图',
                        },
                    ],
                },
                analysis: {
                    title: '报告页先看依据，再决定下一步',
                    subtitle: '这一页用来回答谁最值得先处理、为什么这样排、今天该做什么。AI 只负责继续补一句，不是主入口。',
                    note: '先看本地报告，再决定要不要让 AI 帮你润色一句回复或继续往下拆任务。',
                    steps: [
                        {
                            title: '先选一份报告',
                            body: '左侧报告列表是入口。先点一份报告，再读右侧结论，别一上来就盯 AI 区。',
                            meta: '对应控件：报告列表',
                        },
                        {
                            title: '再看分数和依据',
                            body: '分数不是消息条数，主要看互动频率、双向程度、持续活跃和风险信号。',
                            meta: '对应控件：分数 / 洞察 / 建议',
                        },
                        {
                            title: '最后再用 AI 补一句',
                            body: '如果报告已经告诉你该联系谁、该怎么走，AI 只负责把那句话写得更自然。',
                            meta: '对应控件：AI 继续帮你往下走',
                        },
                    ],
                },
                messages: {
                    title: '消息页先找线程，再补记录或人像',
                    subtitle: '这页更像整理台。先选联系人线程，再决定是补一句聊天内容、让 AI 润色，还是上传头像和截图做人像确认。',
                    note: '如果你只是想知道今天该联系谁，先回联系人页或报告页；消息页更适合补细节和准备下一句。',
                    steps: [
                        {
                            title: '先选左侧线程',
                            body: '左侧线程卡片是入口。先切到你正在处理的人，再看右侧消息流和人像工作区。',
                            meta: '对应控件：线程列表',
                        },
                        {
                            title: '再补一句消息或草稿',
                            body: '底部输入框可以记录聊天内容，也可以先写草稿，再点“AI 润色”让系统帮你整理成更自然的话。',
                            meta: '对应控件：输入框 / AI 润色',
                        },
                        {
                            title: '上传人像只做确认',
                            body: '上传头像或截图后，系统会在你离开本页时再问一次是不是对方本人，不会静默替你确认。',
                            meta: '对应控件：人像识别工作区',
                        },
                    ],
                },
                gifts: {
                    title: '礼物页先选对象，再看预算和理由',
                    subtitle: '这页不是礼物商城。先告诉系统送给谁、什么场景，再看预算区间和推荐理由，最后才决定收藏或带到报告。',
                    note: '如果你还没想清楚关系状态，先回联系人页或报告页；礼物页更适合在对象明确后做选择。',
                    steps: [
                        {
                            title: '先选对象',
                            body: '先在顶部选择联系人，系统才知道要按什么关系类型、亲密度和场景给建议。',
                            meta: '对应控件：对象选择框',
                        },
                        {
                            title: '再看预算和送礼方向',
                            body: '先看建议预算和送礼方向，再决定预算上限，不要一上来就只盯礼物卡片价格。',
                            meta: '对应控件：建议预算 / 送礼方向',
                        },
                        {
                            title: '最后再收藏或带到报告',
                            body: '筛出合适选项后，再用“加入收藏”或“带到报告”把结果留到后续决策里。',
                            meta: '对应控件：礼物卡片按钮',
                        },
                    ],
                },
            };
            const config = configMap[page];
            if (!config) return '';

            return `
                <section class="page-guide-panel">
                    <div class="page-guide-head">
                        <div>
                            <div class="page-guide-kicker">当前页面怎么用</div>
                            <h3 class="panel-title">${escapeHtml(config.title)}</h3>
                            <p class="panel-subtitle">${escapeHtml(config.subtitle)}</p>
                        </div>
                        <div class="detail-actions">
                            <div class="badge">轻教程</div>
                            <button class="chip-btn" data-action="dismiss-page-guide" data-guide="${escapeAttribute(page)}" type="button">知道了</button>
                        </div>
                    </div>
                    <div class="page-guide-grid">
                        ${config.steps.map((item, index) => `
                            <article class="page-guide-card">
                                <div class="page-guide-step">${index + 1}</div>
                                <h4>${escapeHtml(item.title)}</h4>
                                <p>${escapeHtml(item.body)}</p>
                                <div class="page-guide-meta">${escapeHtml(item.meta)}</div>
                            </article>
                        `).join('')}
                    </div>
                    <p class="page-guide-note">${escapeHtml(config.note)}</p>
                </section>
            `;
        }

        function renderJourneySection(page) {
            if (state.settings.journeyGuideDismissed) return '';
            const currentIndex = JOURNEY_FLOW.indexOf(page);
            if (currentIndex === -1) return '';
            const previousPage = JOURNEY_FLOW[currentIndex - 1] || null;
            const nextPage = JOURNEY_FLOW[currentIndex + 1] || null;
            const currentCopy = JOURNEY_COPY[page] || JOURNEY_COPY.dashboard;
            const stepMarkup = JOURNEY_FLOW.map((stepPage, index) => `
                <button class="journey-step-btn ${index === currentIndex ? 'active' : ''} ${index < currentIndex ? 'completed' : ''}" data-nav="${stepPage}" type="button">
                    <span class="journey-step-index">${index + 1}</span>
                    <span class="journey-step-label">${escapeHtml(PAGE_TITLES[stepPage])}</span>
                </button>
            `).join('');
            const nextButtonMarkup = nextPage
                ? `<button class="solid-btn" data-nav="${nextPage}" type="button">下一步：${escapeHtml(PAGE_TITLES[nextPage])}</button>`
                : '<button class="solid-btn" data-nav="dashboard" type="button">首次路径走完，回到总览</button>';
            const previousButtonMarkup = previousPage
                ? `<button class="ghost-btn" data-nav="${previousPage}" type="button">上一步：${escapeHtml(PAGE_TITLES[previousPage])}</button>`
                : '<button class="ghost-btn" data-nav="dashboard" type="button">留在总览</button>';

            return `
                <section class="journey-panel">
                    <div class="journey-head">
                        <div>
                            <div class="journey-kicker">首次使用路径 · 第 ${currentIndex + 1} / ${JOURNEY_FLOW.length} 步</div>
                            <h3 class="panel-title">${escapeHtml(PAGE_TITLES[page])}：${escapeHtml(currentCopy.title)}</h3>
                            <p class="panel-subtitle">${escapeHtml(currentCopy.summary)}</p>
                        </div>
                        <div class="detail-actions">
                            <div class="badge">跨页面引导</div>
                            <button class="chip-btn" data-action="dismiss-journey-guide" type="button">收起路径</button>
                        </div>
                    </div>
                    <div class="journey-steps">${stepMarkup}</div>
                    <div class="journey-actions">
                        ${previousButtonMarkup}
                        ${nextButtonMarkup}
                    </div>
                </section>
            `;
        }

        function renderJourneyCompletionSection(page) {
            if (page !== 'gifts') return '';
            return `
                <section class="journey-finish-panel">
                    <div class="panel-header">
                        <div>
                            <h3 class="panel-title">首次路径走完后，下一步按这个选</h3>
                            <p class="panel-subtitle">网页端到这里已经把关系、报告、消息和礼物都串了一遍。接下来只需要按你的目的继续，不要停在最后一页发愣。</p>
                        </div>
                        <div class="badge">收口区</div>
                    </div>
                    <div class="journey-finish-grid">
                        <article class="journey-finish-card">
                            <h4>继续在线经营</h4>
                            <p>回总览继续看重点对象、最近报告和下一步动作，适合继续在线整理。</p>
                            <div class="detail-actions">
                                <button class="solid-btn" data-nav="dashboard" type="button">回总览继续</button>
                            </div>
                        </article>
                        <article class="journey-finish-card">
                            <h4>导出当前网页数据</h4>
                            <p>把你现在补过的关系、报告和礼物选择导出成网页 JSON，方便留档或发给别人继续看。</p>
                            <div class="detail-actions">
                                <button class="ghost-btn" data-action="export-data" type="button">导出网页数据</button>
                            </div>
                        </article>
                        <article class="journey-finish-card journey-finish-card-note">
                            <h4>真正要直读微信，请切桌面版</h4>
                            <p>网页版到这里为止。真正要读本机微信数据库、处理原始聊天记录、扫描导出和附件补充时，请改用 Windows 桌面版。</p>
                            <div class="journey-finish-note">桌面版负责本地直读，网页版负责在线浏览、整理和导出。</div>
                        </article>
                    </div>
                </section>
            `;
        }

        function sanitizeSecretState(source) {
            return {
                cloudPortraitOptIn: Boolean(source?.cloudPortraitOptIn),
            };
        }

        function loadSecretState() {
            try {
                const raw = localStorage.getItem(SECRET_STORAGE_KEY);
                if (!raw) return cloneData(defaultSecretState);
                const parsed = JSON.parse(raw);
                const sanitized = sanitizeSecretState(parsed);
                if (raw !== JSON.stringify(sanitized)) {
                    localStorage.setItem(SECRET_STORAGE_KEY, JSON.stringify(sanitized));
                }
                return { ...defaultSecretState, ...sanitized };
            } catch (_) {
                return cloneData(defaultSecretState);
            }
        }

        function persistSecretState() {
            secretState = sanitizeSecretState(secretState);
            localStorage.setItem(SECRET_STORAGE_KEY, JSON.stringify(secretState));
        }

        function loadGeoCache() {
            try {
                const raw = localStorage.getItem(GEO_STORAGE_KEY);
                if (!raw) return {};
                const parsed = JSON.parse(raw);
                return parsed && typeof parsed === 'object' ? parsed : {};
            } catch (_) {
                return {};
            }
        }

        function persistGeoCache() {
            localStorage.setItem(GEO_STORAGE_KEY, JSON.stringify(geoCache));
        }

        async function fetchJson(url, options = {}) {
            const response = await fetch(url, {
                credentials: 'same-origin',
                ...options,
            });
            const payload = await response.json().catch(() => ({}));
            if (!response.ok) {
                const error = new Error(payload?.error || `request:${response.status}`);
                error.status = response.status;
                error.payload = payload;
                throw error;
            }
            return payload;
        }

        function buildAppUrl(path) {
            if (typeof window === 'undefined' || !window.location) return path;
            if (!/^https?:/i.test(window.location.href)) return path;
            return new URL(path, window.location.href).toString();
        }

        async function refreshServiceHealth(options = {}) {
            if (serviceHealth.loading) return;
            if (STANDALONE_STATIC_PREVIEW) {
                serviceHealth = {
                    ...createDefaultServiceHealth(),
                    checked: true,
                    loading: false,
                    error: '',
                    aiAvailable: false,
                    portraitAvailable: false,
                    geoAvailable: false,
                    textModel: '静态预览',
                    visionModel: '静态预览',
                };
                if (state.ui.activePage === 'profile') {
                    renderProfile();
                } else if (state.ui.activePage === 'analysis') {
                    renderAnalysis();
                }
                return;
            }
            serviceHealth = { ...serviceHealth, loading: true };
            if (!options.silent && state.ui.activePage === 'profile') {
                renderProfile();
            }
            try {
                const payload = await fetchJson(buildAppUrl(API_HEALTH_ENDPOINT), {
                    headers: { Accept: 'application/json' },
                });
                serviceHealth = {
                    ...createDefaultServiceHealth(),
                    ...payload,
                    checked: true,
                    loading: false,
                    error: '',
                };
            } catch (error) {
                serviceHealth = {
                    ...serviceHealth,
                    checked: true,
                    loading: false,
                    error: String(error?.payload?.error || error?.message || 'health_unavailable'),
                    aiAvailable: false,
                    portraitAvailable: false,
                    geoAvailable: false,
                };
                if (!options.silent) {
                    showToast('服务状态获取失败，当前将继续使用本地兜底');
                }
            }
            if (state.ui.activePage === 'profile') {
                renderProfile();
            } else if (state.ui.activePage === 'analysis') {
                renderAnalysis();
            }
        }

        function approximateDataUrlBytes(dataUrl) {
            const base64 = String(dataUrl || '').split(',')[1] || '';
            const padding = base64.endsWith('==') ? 2 : base64.endsWith('=') ? 1 : 0;
            return Math.max(0, Math.floor(base64.length * 0.75) - padding);
        }

        function getBase64FromDataUrl(dataUrl) {
            return String(dataUrl || '').split(',')[1] || '';
        }

        function loadImageElement(dataUrl) {
            return new Promise((resolve, reject) => {
                const image = new Image();
                image.onload = () => resolve(image);
                image.onerror = () => reject(new Error('image_load_failed'));
                image.src = dataUrl;
            });
        }

        async function sanitizePortraitDataUrl(dataUrl) {
            const image = await loadImageElement(dataUrl);
            let width = image.naturalWidth || image.width || PORTRAIT_MAX_DIMENSION;
            let height = image.naturalHeight || image.height || PORTRAIT_MAX_DIMENSION;
            const largestEdge = Math.max(width, height);
            if (largestEdge > PORTRAIT_MAX_DIMENSION) {
                const scale = PORTRAIT_MAX_DIMENSION / largestEdge;
                width = Math.max(1, Math.round(width * scale));
                height = Math.max(1, Math.round(height * scale));
            }
            const canvas = document.createElement('canvas');
            const context = canvas.getContext('2d', { alpha: false });
            if (!context) throw new Error('canvas_unavailable');
            canvas.width = width;
            canvas.height = height;
            context.fillStyle = '#ffffff';
            context.fillRect(0, 0, width, height);
            context.drawImage(image, 0, 0, width, height);

            let quality = 0.86;
            let currentWidth = width;
            let currentHeight = height;
            let sanitized = canvas.toDataURL('image/jpeg', quality);

            while (approximateDataUrlBytes(sanitized) > PORTRAIT_MAX_BYTES && quality > 0.52) {
                quality -= 0.08;
                sanitized = canvas.toDataURL('image/jpeg', quality);
            }

            while (approximateDataUrlBytes(sanitized) > PORTRAIT_MAX_BYTES && currentWidth > 480 && currentHeight > 480) {
                currentWidth = Math.round(currentWidth * 0.88);
                currentHeight = Math.round(currentHeight * 0.88);
                canvas.width = currentWidth;
                canvas.height = currentHeight;
                context.fillStyle = '#ffffff';
                context.fillRect(0, 0, currentWidth, currentHeight);
                context.drawImage(image, 0, 0, currentWidth, currentHeight);
                sanitized = canvas.toDataURL('image/jpeg', Math.max(0.55, quality));
            }

            return sanitized;
        }

        async function sanitizePortraitFile(file) {
            const originalDataUrl = await readFileAsDataUrl(file);
            return sanitizePortraitDataUrl(originalDataUrl);
        }

        function redactSensitiveText(text, replacements = []) {
            let output = String(text || '').trim();
            replacements.filter(Boolean).forEach((token) => {
                const escaped = token.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
                output = output.replace(new RegExp(escaped, 'g'), '[已隐藏姓名]');
            });
            output = output.replace(/1\d{10}/g, '[已隐藏联系方式]');
            output = output.replace(/https?:\/\/\S+/g, '[已隐藏链接]');
            return output;
        }

        function buildAssistantApiPayload(target, scenario, intent) {
            const budget = getGiftBudgetRecommendation(target, state.ui.giftOccasion);
            const safeScenario = redactSensitiveText(scenario, [target.name, state.profile.name]);
            return {
                targetAlias: TARGET_PLACEHOLDER,
                relationType: target.type,
                importanceLevel: target.importanceTier || 'regular',
                priorityRank: Number(target.importanceRank || 1) || 1,
                weeklyFrequency: Number(target.weeklyFrequency || 0) || 0,
                monthlyDepth: Number(target.monthlyDepth || 0) || 0,
                scenario: safeScenario || '请基于当前关系给出一条温和自然的回应建议。',
                intent,
                occasion: state.ui.giftOccasion,
                portraitTags: Array.isArray(target.portraitProfile?.styleTags) ? target.portraitProfile.styleTags.slice(0, 4) : [],
                giftBudgetLabel: budget.label,
            };
        }

        function replaceTargetPlaceholder(value, targetName) {
            return String(value || '').split(TARGET_PLACEHOLDER).join(targetName || '对方');
        }

        function normalizeAssistantApiResponse(payload, target, intent) {
            const fallback = buildLocalAssistantResponse(target, state.ui.assistantScenario, intent);
            const reply = replaceTargetPlaceholder(payload?.reply || '', target.name).trim();
            return {
                id: `assistant-${Date.now()}`,
                targetId: target.id,
                intent,
                summary: replaceTargetPlaceholder(payload?.summary || fallback.summary, target.name),
                reply: reply || fallback.reply,
                giftAdvice: replaceTargetPlaceholder(payload?.giftAdvice || fallback.giftAdvice, target.name),
                budgetText: replaceTargetPlaceholder(payload?.budgetText || fallback.budgetText, target.name),
                needs: Array.isArray(payload?.needs) ? payload.needs.map((item) => String(item)).filter(Boolean).slice(0, 5) : [],
                source: payload?.source === 'model' && reply ? 'model' : 'local',
                createdAt: formatDate(new Date()),
            };
        }

        function normalizePortraitApiResponse(payload, relationship) {
            const fallback = buildLocalPortraitProfile(null, relationship);
            return {
                appearanceLabel: String(payload?.appearanceLabel || fallback.appearanceLabel),
                summary: String(payload?.summary || fallback.summary),
                styleTags: Array.isArray(payload?.styleTags) ? payload.styleTags.map((entry) => String(entry)).filter(Boolean).slice(0, 4) : fallback.styleTags,
                communicationHints: Array.isArray(payload?.communicationHints) ? payload.communicationHints.map((entry) => String(entry)).filter(Boolean).slice(0, 4) : fallback.communicationHints,
                giftHints: Array.isArray(payload?.giftHints) ? payload.giftHints.map((entry) => String(entry)).filter(Boolean).slice(0, 4) : fallback.giftHints,
                traitTags: Array.isArray(payload?.traitTags) ? payload.traitTags.map((entry) => String(entry)).filter(Boolean).slice(0, 3) : fallback.traitTags,
                source: payload?.source === 'model' ? 'model' : 'local',
                analyzedAt: formatDate(new Date()),
            };
        }

        function groupByType(items) {
            return items.reduce((map, item) => {
                map[item.type] = (map[item.type] || 0) + 1;
                return map;
            }, {});
        }

        function clamp(value, min, max) {
            return Math.min(Math.max(value, min), max);
        }

        function formatDate(date) {
            const year = date.getFullYear();
            const month = String(date.getMonth() + 1).padStart(2, '0');
            const day = String(date.getDate()).padStart(2, '0');
            return `${year}-${month}-${day}`;
        }

        function daysSince(dateString) {
            if (!dateString) return -1;
            const current = new Date(formatDate(new Date()));
            const target = new Date(dateString);
            return Math.round((current.getTime() - target.getTime()) / 86400000);
        }

        function daysUntilBirthday(value) {
            const [month, day] = (value || '').split('-').map(Number);
            if (!month || !day) return null;
            const now = new Date();
            let target = new Date(now.getFullYear(), month - 1, day);
            if (target < new Date(formatDate(now))) target = new Date(now.getFullYear() + 1, month - 1, day);
            return Math.round((target.getTime() - new Date(formatDate(now)).getTime()) / 86400000);
        }

        function intimacyLevel(score) {
            if (score >= 85) return '核心';
            if (score >= 70) return '稳定';
            if (score >= 55) return '可提升';
            return '待激活';
        }

        function getNodeColors(type) {
            switch (type) {
                case 'family': return 'linear-gradient(135deg, #cb6d4b, #e69b7e)';
                case 'partner': return 'linear-gradient(135deg, #9e5a75, #c5849e)';
                case 'colleague': return 'linear-gradient(135deg, #2f8c7a, #6fb8aa)';
                case 'mentor': return 'linear-gradient(135deg, #4e5f7f, #7c8cac)';
                case 'classmate': return 'linear-gradient(135deg, #d8a53b, #e6c97b)';
                default: return 'linear-gradient(135deg, #a64f33, #cb6d4b)';
            }
        }

        function delay(ms) {
            return new Promise((resolve) => setTimeout(resolve, ms));
        }

        function getGeoCacheKey(value) {
            return String(value || '').trim().toLowerCase();
        }

        function findRelationshipById(id) {
            return state.relationships.find((item) => item.id === id) || null;
        }

        function deriveWeeklyFrequencyFromLastContact(dateString) {
            const since = daysSince(dateString);
            if (since <= 1) return 7;
            if (since <= 3) return 5;
            if (since <= 7) return 3;
            if (since <= 14) return 2;
            if (since <= 30) return 1;
            return 0;
        }

        function deriveMonthlyDepthFromLegacy(item) {
            const intimacy = Number(item.intimacy || 0);
            if (intimacy >= 90) return 6;
            if (intimacy >= 80) return 4;
            if (intimacy >= 68) return 3;
            if (intimacy >= 55) return 2;
            if (intimacy >= 40) return 1;
            return 0;
        }

        function getImportanceRank(item) {
            if (item.importanceTier !== 'important') return 0;
            return clamp(Number(item.importanceRank || 3), 1, 5);
        }

        function getImportanceDisplay(item) {
            if (item.importanceTier !== 'important') return IMPORTANCE_LABELS.regular;
            return `重要关系 · 第 ${getImportanceRank(item)} 顺位`;
        }

        function getSuggestedWeeklyFrequency(item) {
            const base = RELATION_WEEKLY_TARGET[item.type] || 2;
            return item.importanceTier === 'important' ? base + 1 : base;
        }

        function getSuggestedMonthlyDepth(item) {
            const base = RELATION_MONTHLY_TARGET[item.type] || 2;
            return item.importanceTier === 'important' ? base + 1 : base;
        }

        function getCadenceGap(item) {
            return Math.max(0, getSuggestedWeeklyFrequency(item) - Number(item.weeklyFrequency || 0));
        }

        function getDepthGap(item) {
            return Math.max(0, getSuggestedMonthlyDepth(item) - Number(item.monthlyDepth || 0));
        }

        function computeRelationshipIntimacy(item) {
            const base = RELATION_BASE_INTIMACY[item.type] || 36;
            const weeklyFrequency = clamp(Number(item.weeklyFrequency || 0), 0, 14);
            const monthlyDepth = clamp(Number(item.monthlyDepth || 0), 0, 12);
            const importanceBonus = item.importanceTier === 'important'
                ? 10 + (6 - getImportanceRank(item)) * 2
                : 0;
            return clamp(
                Math.round(base + weeklyFrequency * 3 + monthlyDepth * 2 + importanceBonus),
                28,
                98,
            );
        }

        function normalizeRelationship(item) {
            const relationship = {
                ...item,
                tags: Array.isArray(item.tags) ? item.tags.filter(Boolean) : [],
            };
            relationship.portraitProfile = item?.portraitProfile && typeof item.portraitProfile === 'object'
                ? {
                    appearanceLabel: String(item.portraitProfile.appearanceLabel || ''),
                    summary: String(item.portraitProfile.summary || ''),
                    source: String(item.portraitProfile.source || 'local'),
                    analyzedAt: String(item.portraitProfile.analyzedAt || ''),
                    styleTags: Array.isArray(item.portraitProfile.styleTags) ? item.portraitProfile.styleTags.map((entry) => String(entry)).filter(Boolean) : [],
                    communicationHints: Array.isArray(item.portraitProfile.communicationHints) ? item.portraitProfile.communicationHints.map((entry) => String(entry)).filter(Boolean) : [],
                    giftHints: Array.isArray(item.portraitProfile.giftHints) ? item.portraitProfile.giftHints.map((entry) => String(entry)).filter(Boolean) : [],
                    traitTags: Array.isArray(item.portraitProfile.traitTags) ? item.portraitProfile.traitTags.map((entry) => String(entry)).filter(Boolean) : [],
                }
                : null;
            relationship.lastContact = relationship.lastContact || '';
            relationship.weeklyFrequency = clamp(
                Number.isFinite(Number(item.weeklyFrequency))
                    ? Number(item.weeklyFrequency)
                    : deriveWeeklyFrequencyFromLastContact(relationship.lastContact),
                0,
                14,
            );
            relationship.monthlyDepth = clamp(
                Number.isFinite(Number(item.monthlyDepth))
                    ? Number(item.monthlyDepth)
                    : deriveMonthlyDepthFromLegacy(item),
                0,
                12,
            );
            relationship.importanceTier = item.importanceTier === 'important'
                ? 'important'
                : Number(item.intimacy || 0) >= 88
                    ? 'important'
                    : 'regular';
            relationship.importanceRank = relationship.importanceTier === 'important'
                ? clamp(
                    Number.isFinite(Number(item.importanceRank))
                        ? Number(item.importanceRank)
                        : Number(item.intimacy || 0) >= 92
                            ? 1
                            : 3,
                    1,
                    5,
                )
                : 0;
            relationship.intimacy = computeRelationshipIntimacy(relationship);
            return relationship;
        }

        function getSelectedGiftRelationship() {
            return findRelationshipById(state.ui.selectedGiftRelationshipId)
                || state.relationships.find((item) => item.type === state.ui.giftRelation)
                || state.relationships[0]
                || null;
        }

        function getSelectedMessageRelationship() {
            return findRelationshipById(state.ui.selectedMessageRelationshipId)
                || state.relationships[0]
                || null;
        }

        function getMessageDraft(relationshipId) {
            if (!relationshipId) return '';
            return String(state.messageDrafts?.[relationshipId] || '');
        }

        function setMessageDraft(relationshipId, value) {
            if (!relationshipId) return;
            state.messageDrafts = {
                ...(state.messageDrafts || {}),
                [relationshipId]: String(value || ''),
            };
        }

        function clearMessageDraft(relationshipId) {
            if (!relationshipId || !state.messageDrafts) return;
            const nextDrafts = { ...state.messageDrafts };
            delete nextDrafts[relationshipId];
            state.messageDrafts = nextDrafts;
        }

        function getManualMessagesForRelationship(relationshipId) {
            return (state.manualMessages || [])
                .filter((item) => item.relationshipId === relationshipId)
                .sort((a, b) => String(a.createdAt).localeCompare(String(b.createdAt)));
        }

        function autoResizeMessageComposer() {
            const input = document.getElementById('message-composer');
            if (!input) return;
            input.style.height = 'auto';
            const nextHeight = Math.min(Math.max(input.scrollHeight, 24), 132);
            input.style.height = `${nextHeight}px`;
        }

        function getMessageChannel(item) {
            if (item.type === 'partner' || item.type === 'friend') return '微信';
            if (item.type === 'colleague' || item.type === 'mentor') return '企业微信';
            if (item.type === 'family') return '家庭群';
            return '消息';
        }

        function getMessageThreads() {
            return state.relationships
                .slice()
                .sort((a, b) => {
                    if (a.importanceTier !== b.importanceTier) return a.importanceTier === 'important' ? -1 : 1;
                    if (getImportanceRank(a) !== getImportanceRank(b)) return getImportanceRank(a) - getImportanceRank(b);
                    return Math.max(0, daysSince(a.lastContact)) - Math.max(0, daysSince(b.lastContact));
                })
                .map((relationship) => ({
                    relationship,
                    channel: getMessageChannel(relationship),
                    unread: clamp(getCadenceGap(relationship) + getDepthGap(relationship), 0, 3),
                    summary: relationship.note || inferRelationshipNeeds(relationship).toneSummary,
                }));
        }

        function buildMessageStream(item) {
            const assistantRecord = state.assistantHistory.find((entry) => entry.targetId === item.id);
            const needs = inferRelationshipNeeds(item);
            const lastGap = daysSince(item.lastContact);
            const baseStream = [
                {
                    role: 'other',
                    text: item.note || '最近有点忙，等我把手上的事处理完再细聊。',
                    meta: `${getMessageChannel(item)} · ${lastGap >= 0 ? `${lastGap} 天前` : '最近'}`,
                },
                {
                    role: 'me',
                    text: assistantRecord?.reply || buildLocalAssistantResponse(item, '', '问候').reply,
                    meta: '我 · 最近建议话术',
                },
                {
                    role: 'other',
                    text: needs.toneSummary,
                    meta: '系统根据当前互动节奏整理',
                },
            ];
            const manualStream = getManualMessagesForRelationship(item.id).map((entry) => ({
                role: entry.role,
                text: entry.text,
                meta: entry.meta || `${entry.role === 'me' ? '我' : item.name} · 手动输入`,
            }));
            return [...baseStream, ...manualStream];
        }

        function readFileAsDataUrl(file) {
            return new Promise((resolve, reject) => {
                const reader = new FileReader();
                reader.onload = () => resolve(String(reader.result || ''));
                reader.onerror = () => reject(reader.error || new Error('file_read_failed'));
                reader.readAsDataURL(file);
            });
        }

        async function queuePortraitCandidate(file) {
            const relationship = getSelectedMessageRelationship();
            if (!relationship || !file) return;
            const dataUrl = await sanitizePortraitFile(file);
            portraitReviewState.candidate = {
                relationshipId: relationship.id,
                relationshipName: relationship.name,
                fileName: file.name || 'portrait-image',
                dataUrl,
                capturedAt: formatDate(new Date()),
            };
            portraitReviewState.pendingPage = null;
            portraitReviewState.analyzing = false;
            renderMessages();
            showToast(`已检测到 ${relationship.name} 的待确认人像，离开消息页时会提醒你确认`);
        }

        function setPortraitModalBusyState() {
            const confirmButton = document.querySelector('#portrait-review-modal [data-action="confirm-portrait-candidate"]');
            const rejectButton = document.querySelector('#portrait-review-modal [data-action="reject-portrait-candidate"]');
            const stayButtons = document.querySelectorAll('#portrait-review-modal [data-action="stay-on-messages"]');
            if (confirmButton) {
                confirmButton.disabled = portraitReviewState.analyzing;
                confirmButton.textContent = portraitReviewState.analyzing ? '正在分析...' : '是，开始分析';
            }
            if (rejectButton) rejectButton.disabled = portraitReviewState.analyzing;
            stayButtons.forEach((button) => {
                button.disabled = portraitReviewState.analyzing;
            });
        }

        function renderPortraitReviewBody() {
            const host = document.getElementById('portrait-review-body');
            const candidate = portraitReviewState.candidate;
            if (!host) return;
            if (!candidate) {
                host.innerHTML = '<div class="empty-state">当前没有待确认的人像。</div>';
                setPortraitModalBusyState();
                return;
            }
            const relationship = findRelationshipById(candidate.relationshipId);
            host.innerHTML = `
                <div class="portrait-modal-grid">
                    <img class="portrait-preview" src="${escapeAttribute(candidate.dataUrl)}" alt="${escapeAttribute(candidate.relationshipName)} 的待确认人像">
                    <div class="portrait-modal-copy">
                        <div>
                            <strong>${escapeHtml(candidate.relationshipName)}</strong>
                            <p class="portrait-copy">系统在消息工作台里检测到一张可能属于对方的人像。确认后会尝试用 AI 生成外在印象分类，并把结果写入这位联系人的档案。</p>
                        </div>
                        <div class="portrait-status">
                            ${relationship?.portraitProfile?.summary
                                ? `当前已有人像档案：${escapeHtml(relationship.portraitProfile.summary)}`
                                : '当前还没有这位联系人的人像档案。'}
                        </div>
                        <div class="portrait-tip-list">
                            <div class="portrait-tip">确认后会生成外在印象分类、沟通提示和送礼偏好补充。</div>
                            <div class="portrait-tip">如果这不是对方本人，直接点“不是对方”即可丢弃，不会写入联系人资料。</div>
                            <div class="portrait-tip">${secretState.cloudPortraitOptIn ? '当前已允许云端人像分析；上传前图片会先压缩并去除元数据。' : '当前默认关闭云端人像分析；你首次确认时可以决定是否只用本地规则。'}</div>
                        </div>
                    </div>
                </div>
            `;
            setPortraitModalBusyState();
        }

        function openPortraitReviewModal(nextPage) {
            portraitReviewState.pendingPage = nextPage;
            renderPortraitReviewBody();
            const modal = document.getElementById('portrait-review-modal');
            if (!modal) return;
            modal.classList.add('open');
            modal.setAttribute('aria-hidden', 'false');
        }

        function closePortraitReviewModal() {
            const modal = document.getElementById('portrait-review-modal');
            if (!modal) return;
            modal.classList.remove('open');
            modal.setAttribute('aria-hidden', 'true');
            portraitReviewState.pendingPage = null;
            portraitReviewState.analyzing = false;
        }

        function requestPageChange(nextPage, options = {}) {
            const normalized = AVAILABLE_PAGES.includes(nextPage) ? nextPage : 'dashboard';
            if (!options.force && state.ui.activePage === 'messages' && normalized !== 'messages' && portraitReviewState.candidate) {
                openPortraitReviewModal(normalized);
                return false;
            }
            const previousPage = state.ui.activePage;
            syncSelection();
            state.ui.activePage = normalized;
            renderNavigation();
            const pageMeta = document.getElementById('page-meta');
            if (pageMeta) {
                pageMeta.textContent = PAGE_SWITCH_HINTS[normalized] || PAGE_META[normalized] || '';
            }
            renderPageSkeleton(normalized);
            persistState();
            if (normalized !== previousPage && typeof window !== 'undefined' && typeof window.scrollTo === 'function') {
                window.scrollTo({ top: 0, behavior: 'smooth' });
            }
            if (pageTransitionFrame && typeof cancelAnimationFrame === 'function') {
                cancelAnimationFrame(pageTransitionFrame);
            }
            const finalizePageChange = () => {
                pageTransitionFrame = null;
                renderActivePage();
                persistState();
            };
            if (typeof requestAnimationFrame === 'function') {
                pageTransitionFrame = requestAnimationFrame(finalizePageChange);
            } else {
                setTimeout(finalizePageChange, 16);
            }
            return true;
        }

        function renderPageSkeleton(pageName) {
            const host = document.getElementById(`page-${pageName}`);
            if (!host) return;
            host.innerHTML = `
                <div class="page-skeleton">
                    <div class="page-skeleton-copy">${escapeHtml(PAGE_SWITCH_HINTS[pageName] || '正在准备页面内容...')}</div>
                    <div class="skeleton-grid">
                        <div class="skeleton-card">
                            <div class="skeleton-line short"></div>
                            <div class="skeleton-line long"></div>
                            <div class="skeleton-line medium"></div>
                        </div>
                        <div class="skeleton-card">
                            <div class="skeleton-line short"></div>
                            <div class="skeleton-line medium"></div>
                            <div class="skeleton-line long"></div>
                        </div>
                        <div class="skeleton-card tall">
                            <div class="skeleton-line short"></div>
                            <div class="skeleton-line long"></div>
                            <div class="skeleton-line long"></div>
                            <div class="skeleton-line medium"></div>
                        </div>
                    </div>
                </div>
            `;
        }

        function renderAiTaskModalContent() {
            const host = document.getElementById('ai-task-body');
            if (!host) return;
            const target = findRelationshipById(state.ui.assistantTargetId) || state.relationships[0] || null;
            const latestAssistant = target ? getLatestAssistantRecordForTarget(target.id) : getLatestAssistantRecord();
            const needs = target ? inferRelationshipNeeds(target) : null;
            const budget = target ? getGiftBudgetRecommendation(target, state.ui.giftOccasion) : null;
            const portraitProfile = target?.portraitProfile || null;
            host.innerHTML = target ? `
                <div class="task-modal-stack">
                    <div class="field-grid">
                        <div class="field">
                            <label for="ai-task-target">回应对象</label>
                            <select class="select" id="ai-task-target">
                                ${state.relationships.map((item) => `<option value="${item.id}" ${target.id === item.id ? 'selected' : ''}>${escapeHtml(item.name)} · ${RELATION_LABELS[item.type]}</option>`).join('')}
                            </select>
                        </div>
                        <div class="field">
                            <label for="ai-task-intent">沟通目的</label>
                            <select class="select" id="ai-task-intent">
                                ${ASSISTANT_INTENTS.map((intent) => `<option value="${intent}" ${state.ui.assistantIntent === intent ? 'selected' : ''}>${intent}</option>`).join('')}
                            </select>
                        </div>
                        <div class="field full">
                            <label for="ai-task-scenario">任务内容</label>
                            <textarea class="textarea" id="ai-task-scenario" rows="5" placeholder="例如：帮我给她回一条温和一点的消息，语气自然，不要像模板。">${escapeHtml(state.ui.assistantScenario)}</textarea>
                        </div>
                    </div>
                    <div class="assistant-pill-row">
                        <div class="distance-pill">对象偏好 · ${escapeHtml(needs?.personalitySummary || '待选择')}</div>
                        <div class="distance-pill">建议礼值 · ${escapeHtml(budget?.label || '待选择')}</div>
                        ${portraitProfile ? `<div class="distance-pill">外在印象 · ${escapeHtml(portraitProfile.appearanceLabel)}</div>` : ''}
                    </div>
                    <div class="task-modal-note">
                        ${portraitProfile
                            ? `当前已识别到这位联系人的人像风格：${escapeHtml(portraitProfile.summary)}`
                            : '当前还没有这位联系人的人像档案。你也可以先去消息页上传头像或截图，再回来继续生成回应。'}
                    </div>
                    ${latestAssistant ? renderAssistantResult(latestAssistant, 'copy-ai-task-reply') : '<div class="empty-state">先填写任务内容，再点击“生成 AI 回应”。</div>'}
                </div>
            ` : '<div class="empty-state">先新增一位联系人，AI 任务框才知道要为谁生成内容。</div>';
            const generateButton = document.querySelector('#ai-task-modal [data-action="generate-ai-task-reply"]');
            if (generateButton) {
                generateButton.disabled = aiPending;
                generateButton.textContent = aiPending ? '正在生成...' : '生成 AI 回应';
            }
        }

        function openAiTaskModal(targetId = null) {
            if (targetId && findRelationshipById(targetId)) {
                state.ui.assistantTargetId = targetId;
                state.ui.selectedRelationshipId = targetId;
                state.ui.selectedMessageRelationshipId = targetId;
            }
            renderAiTaskModalContent();
            const modal = document.getElementById('ai-task-modal');
            if (!modal) return;
            modal.classList.add('open');
            modal.setAttribute('aria-hidden', 'false');
        }

        function closeAiTaskModal() {
            const modal = document.getElementById('ai-task-modal');
            if (!modal) return;
            modal.classList.remove('open');
            modal.setAttribute('aria-hidden', 'true');
        }

        function buildLocalPortraitProfile(candidate, relationship) {
            const fileName = String(candidate?.fileName || '').toLowerCase();
            const presets = {
                mentor: {
                    appearanceLabel: PORTRAIT_LABELS.professional,
                    styleTags: ['专业', '清爽', '克制'],
                    communicationHints: ['适合先给结论，再补充细节', '语气温和但不要太跳脱'],
                    giftHints: ['更适合稳妥、有内容感的礼物', '尽量避免太夸张或过度私人化'],
                    traitTags: ['formal', 'practical'],
                },
                colleague: {
                    appearanceLabel: PORTRAIT_LABELS.minimal,
                    styleTags: ['利落', '简洁', '通勤感'],
                    communicationHints: ['适合明确、低打扰的表达', '把重点放在安排和进度上'],
                    giftHints: ['更适合实用型、不过界的礼物', '预算不宜过高，避免压力'],
                    traitTags: ['practical', 'formal'],
                },
                partner: {
                    appearanceLabel: PORTRAIT_LABELS.refined,
                    styleTags: ['精致', '有仪式感', '在意氛围'],
                    communicationHints: ['适合带一点情绪价值和陪伴感', '表达可以更柔和、更贴近细节'],
                    giftHints: ['礼物可以更看重仪式感和心意', '风格统一会比单纯贵更有效'],
                    traitTags: ['sentimental', 'comfort', 'novelty'],
                },
                family: {
                    appearanceLabel: PORTRAIT_LABELS.warm,
                    styleTags: ['自然', '亲和', '松弛'],
                    communicationHints: ['更适合先关心近况', '表达里可以保留陪伴感'],
                    giftHints: ['适合舒适、关怀类礼物', '实用中带一点心意会更自然'],
                    traitTags: ['comfort', 'sentimental'],
                },
                classmate: {
                    appearanceLabel: PORTRAIT_LABELS.energetic,
                    styleTags: ['年轻感', '轻松', '有活力'],
                    communicationHints: ['适合从共同回忆或活动切入', '语气可以更轻松一点'],
                    giftHints: ['适合有趣、有参与感的小礼物', '不用过重，轻巧更自然'],
                    traitTags: ['social', 'novelty'],
                },
                friend: {
                    appearanceLabel: PORTRAIT_LABELS.artistic,
                    styleTags: ['细腻', '有生活感', '有审美'],
                    communicationHints: ['适合具体、自然、不模板的表达', '可以从最近生活状态切入'],
                    giftHints: ['更适合有风格、带情绪价值的礼物', '选择上可以比同事关系更有个性'],
                    traitTags: ['sentimental', 'social', 'novelty'],
                },
            };
            const base = presets[relationship.type] || presets.friend;
            let appearanceLabel = base.appearanceLabel;
            if (fileName.includes('work') || fileName.includes('office')) appearanceLabel = PORTRAIT_LABELS.professional;
            if (fileName.includes('sport') || fileName.includes('run')) appearanceLabel = PORTRAIT_LABELS.energetic;
            return {
                appearanceLabel,
                summary: `${relationship.name} 的外在印象更偏“${appearanceLabel}”，适合沿着 ${base.styleTags.slice(0, 2).join(' / ')} 的方向去理解沟通和送礼偏好。`,
                styleTags: base.styleTags,
                communicationHints: base.communicationHints,
                giftHints: base.giftHints,
                traitTags: base.traitTags,
                source: 'local',
                analyzedAt: formatDate(new Date()),
            };
        }

        function applyPortraitProfileToRelationship(relationshipId, profile) {
            const index = state.relationships.findIndex((item) => item.id === relationshipId);
            if (index === -1) return;
            state.relationships[index] = normalizeRelationship({
                ...state.relationships[index],
                portraitProfile: profile,
            });
        }

        async function analyzePortraitCandidate(candidate, relationship) {
            if (secretState.cloudPortraitOptIn) {
                const payload = await fetchJson(buildAppUrl(AI_PORTRAIT_ENDPOINT), {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify({
                        relationshipAlias: TARGET_PLACEHOLDER,
                        imageBase64: getBase64FromDataUrl(candidate.dataUrl),
                    }),
                });
                return normalizePortraitApiResponse(payload, relationship);
            }
            await delay(180);
            return buildLocalPortraitProfile(candidate, relationship);
        }

        function getLatestAssistantRecord() {
            return state.assistantHistory[0] || null;
        }

        function getLatestAssistantRecordForTarget(targetId) {
            if (!targetId) return getLatestAssistantRecord();
            return state.assistantHistory.find((item) => item.targetId === targetId) || getLatestAssistantRecord();
        }

        function getPortraitTraitBoost(item, key) {
            const traits = item?.portraitProfile?.traitTags || [];
            return traits.includes(key) ? 12 : 0;
        }

        function collectRelationshipText(item) {
            return [
                item.note,
                item.city,
                ...(item.tags || []),
                RELATION_LABELS[item.type] || '',
                item.portraitProfile?.appearanceLabel || '',
                ...(item.portraitProfile?.styleTags || []),
            ]
                .filter(Boolean)
                .join(' ');
        }

        function keywordScore(text, keywords) {
            return keywords.reduce((sum, keyword) => sum + (text.includes(keyword) ? 1 : 0), 0);
        }

        function inferRelationshipNeeds(item) {
            const text = collectRelationshipText(item);
            const practical = clamp(38 + keywordScore(text, ['项目', '合作', '进度', '工作', '安排', '反馈', '职业', '简洁', '克制']) * 11 + getPortraitTraitBoost(item, 'practical') + (['colleague', 'mentor'].includes(item.type) ? 16 : 0), 24, 96);
            const sentimental = clamp(42 + keywordScore(text, ['纪念', '回家', '想念', '回忆', '家人', '生日', '见面', '细腻', '仪式']) * 10 + getPortraitTraitBoost(item, 'sentimental') + (['family', 'partner'].includes(item.type) ? 18 : 0), 24, 96);
            const comfort = clamp(36 + keywordScore(text, ['忙', '累', '休息', '健康', '照顾', '周末', '亲和', '自然']) * 10 + getPortraitTraitBoost(item, 'comfort') + (['family', 'partner'].includes(item.type) ? 16 : 0), 22, 96);
            const formal = clamp(24 + keywordScore(text, ['导师', '项目', '反馈', '合作', '拜访', '专业', '稳重']) * 12 + getPortraitTraitBoost(item, 'formal') + (['mentor', 'colleague'].includes(item.type) ? 22 : 0), 18, 94);
            const novelty = clamp(30 + keywordScore(text, ['见面', '活动', '副业', '旅行', '同学', '文艺', '精致']) * 10 + getPortraitTraitBoost(item, 'novelty') + (['friend', 'classmate'].includes(item.type) ? 14 : 0), 18, 92);
            const social = clamp(34 + keywordScore(text, ['见面', '合作', '一起', '朋友', '同学', '活力', '社交']) * 9 + getPortraitTraitBoost(item, 'social') + (['friend', 'classmate', 'partner'].includes(item.type) ? 12 : 0), 20, 94);
            const vector = { practical, sentimental, comfort, formal, novelty, social };
            const dominant = Object.entries(vector)
                .sort((a, b) => b[1] - a[1])
                .slice(0, 2)
                .map(([key]) => TRAIT_LABELS[key] || key);
            const needs = [];
            if (daysSince(item.lastContact) >= 14) needs.push('需要被温和地重新连接');
            if (item.type === 'mentor' || item.type === 'colleague') needs.push('更在意明确、低打扰和尊重感');
            if (item.portraitProfile?.summary) needs.push(`外在印象更偏 ${item.portraitProfile.appearanceLabel || '当前识别风格'}`);
            if (sentimental >= 72) needs.push('更容易被情绪价值和回忆触发');
            if (comfort >= 72) needs.push('更适合收到带关心感的表达');
            if (practical >= 72) needs.push('对实用和具体帮助会更有感受');
            if (!needs.length) needs.push('适合自然、具体、不施压的表达方式');
            return {
                vector,
                dominant,
                needs,
                personalitySummary: `更偏 ${dominant.join(' / ')}，建议少一点模板感，多一点贴近近况的表达。`,
                toneSummary: item.type === 'mentor' || item.type === 'colleague'
                    ? '语气以温和、明确、不过分热烈为主'
                    : item.type === 'partner' || item.type === 'family'
                        ? '语气可以更有陪伴感和关心感'
                        : '语气适合轻松、自然、留有余地',
            };
        }

        function formatCurrencyRange(min, max) {
            return `¥${min} - ¥${max}`;
        }

        function getGiftBudgetRecommendation(item, occasion = state.ui.giftOccasion) {
            const base = RELATION_BUDGET_BASES[item.type] || { min: 120, max: 320 };
            const intimacyFactor = 1 + (Number(item.intimacy || 0) - 60) / 140;
            const occasionFactor = occasion === '纪念日' ? 1.14 : occasion === '生日' ? 1.06 : occasion === '节日' ? 0.96 : 0.88;
            const birthdayBoost = item.birthday && daysUntilBirthday(item.birthday) !== null && daysUntilBirthday(item.birthday) <= 10 ? 1.08 : 1;
            const needs = inferRelationshipNeeds(item);
            const emotionalBoost = needs.vector.sentimental >= 76 && ['纪念日', '生日'].includes(occasion) ? 1.08 : 1;
            const min = clamp(Math.round(base.min * intimacyFactor * occasionFactor), 80, 1500);
            const max = clamp(Math.round(base.max * intimacyFactor * occasionFactor * birthdayBoost * emotionalBoost), min + 60, 2200);
            const target = Math.round((min + max) / 2);
            let level = '平衡型';
            if (target >= 850) level = '高投入';
            else if (target >= 420) level = '重点型';
            else if (target <= 180) level = '轻心意';
            return {
                min,
                max,
                target,
                level,
                label: formatCurrencyRange(min, max),
                reason: `${RELATION_LABELS[item.type]} + ${occasion} 场景下，更适合 ${level} 的价值表达；当前亲密度 ${item.intimacy} 也会把预算带到 ${formatCurrencyRange(min, max)}。`,
            };
        }

        function computeGiftTraitScore(tags, vector) {
            if (!tags || !tags.length) return 0;
            const total = tags.reduce((sum, tag) => sum + Number(vector[tag] || 0), 0);
            return total / tags.length;
        }

        function scoreGiftForRelationship(gift, relationship, occasion = state.ui.giftOccasion) {
            const budget = getGiftBudgetRecommendation(relationship, occasion);
            const needs = inferRelationshipNeeds(relationship);
            let score = 42;
            if (gift.relationTypes.includes(relationship.type)) score += 16;
            if (gift.occasion.includes(occasion)) score += 12;
            score += Math.round(computeGiftTraitScore(gift.personaTags, needs.vector) / 6);
            const tolerance = Math.max(120, Math.round((budget.max - budget.min) * 0.92));
            const gap = Math.abs(gift.price - budget.target);
            score += clamp(Math.round(24 - gap / tolerance * 24), -12, 24);
            if (gift.price < budget.min * 0.72 && relationship.intimacy >= 85 && occasion !== '拜访') score -= 8;
            if (gift.price > budget.max * 1.38 && relationship.type !== 'partner') score -= 10;
            return clamp(score, 35, 98);
        }

        function formatDistanceKm(value) {
            if (typeof value !== 'number' || Number.isNaN(value)) return '待计算';
            if (value >= 100) return `${Math.round(value)} km`;
            return `${value.toFixed(1)} km`;
        }

        function calculateDistanceKm(source, target) {
            if (!source || !target) return null;
            const toRad = (value) => value * Math.PI / 180;
            const earthRadius = 6371;
            const latDiff = toRad(target.lat - source.lat);
            const lngDiff = toRad(target.lng - source.lng);
            const lat1 = toRad(source.lat);
            const lat2 = toRad(target.lat);
            const a = Math.sin(latDiff / 2) ** 2 + Math.cos(lat1) * Math.cos(lat2) * Math.sin(lngDiff / 2) ** 2;
            return earthRadius * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        }

        function getCachedLocation(query) {
            const key = getGeoCacheKey(query);
            return key ? geoCache[key] || null : null;
        }

        function getCachedDistanceForRelationship(item) {
            const source = getCachedLocation(state.profile.city);
            const target = getCachedLocation(item.city);
            return source && target ? calculateDistanceKm(source, target) : null;
        }

        async function geocodeQuery(query) {
            const trimmed = String(query || '').trim();
            const key = getGeoCacheKey(trimmed);
            if (!key) return null;
            if (geoCache[key] && !geoCache[key].missing) return geoCache[key];
            if (STANDALONE_STATIC_PREVIEW) {
                geoCache[key] = { missing: true, query: trimmed, reason: 'standalone_preview', updatedAt: formatDate(new Date()) };
                persistGeoCache();
                return null;
            }
            const url = new URL(buildAppUrl(GEO_ENDPOINT), window.location.href);
            url.searchParams.set('q', trimmed);
            const data = await fetchJson(url.toString(), {
                headers: { Accept: 'application/json' },
            });
            if (data?.missing || !Number.isFinite(Number(data?.lat)) || !Number.isFinite(Number(data?.lng))) {
                geoCache[key] = { missing: true, query: trimmed, updatedAt: formatDate(new Date()) };
                persistGeoCache();
                return null;
            }
            const record = {
                query: trimmed,
                lat: Number(data.lat),
                lng: Number(data.lng),
                label: data.label || trimmed,
                updatedAt: formatDate(new Date()),
            };
            geoCache[key] = record;
            persistGeoCache();
            await delay(GEO_LOOKUP_INTERVAL);
            return record;
        }

        async function resolveDistanceLocations(queries, token) {
            const result = {};
            for (const query of queries) {
                if (token !== relationshipMapToken) return null;
                const key = getGeoCacheKey(query);
                if (!key) continue;
                const cached = geoCache[key];
                if (cached && !cached.missing) {
                    result[key] = cached;
                    continue;
                }
                if (cached && cached.missing) continue;
                try {
                    const record = await geocodeQuery(query);
                    if (record) result[key] = record;
                } catch (error) {
                    console.error(error);
                }
            }
            return result;
        }

        async function renderRelationshipDistanceMap(items, selected) {
            const host = document.getElementById('relationship-map');
            const meta = document.getElementById('relationship-map-meta');
            const pills = document.getElementById('relationship-distance-pills');
            if (!host || state.ui.relationView !== 'graph') return;
            if (relationshipMap) {
                relationshipMap.remove();
                relationshipMap = null;
            }
            if (typeof window === 'undefined' || !window.L) {
                host.innerHTML = '<div class="empty-state">地图资源加载失败，请检查网络后刷新页面。</div>';
                return;
            }

            const token = ++relationshipMapToken;
            host.innerHTML = '<div class="empty-state">正在根据城市定位关系距离，首次打开会稍慢一点。</div>';
            if (meta) meta.textContent = '距离会以“我的城市”为起点，向每位联系人绘制虚线并标注公里数。';
            if (pills) pills.innerHTML = '';

            const meCity = String(state.profile.city || '').trim();
            if (!meCity) {
                host.innerHTML = '<div class="empty-state">请先在“我的”页面填写你的所在城市，地图才能计算距离。</div>';
                return;
            }

            const uniqueQueries = [...new Set([meCity, ...items.map((item) => item.city).filter(Boolean)])];
            const resolved = await resolveDistanceLocations(uniqueQueries, token);
            if (!resolved || token !== relationshipMapToken || state.ui.relationView !== 'graph') return;

            const mePoint = resolved[getGeoCacheKey(meCity)] || getCachedLocation(meCity);
            const mappedItems = items
                .map((item) => ({
                    item,
                    point: resolved[getGeoCacheKey(item.city)] || getCachedLocation(item.city),
                }))
                .filter((entry) => entry.point && mePoint);

            if (!mePoint || !mappedItems.length) {
                host.innerHTML = '<div class="empty-state">还没有足够的城市坐标可用于绘图，请先补全城市名称，或部署到 HTTP 静态站点后再试。</div>';
                if (meta) meta.textContent = '公开地理编码服务需要有效的网页来源，直接双击本地文件时可能会被限制。';
                return;
            }

            host.innerHTML = '';
            relationshipMap = window.L.map(host, {
                zoomControl: true,
                scrollWheelZoom: false,
            });

            const meLatLng = window.L.latLng(mePoint.lat, mePoint.lng);
            const bounds = window.L.latLngBounds([meLatLng]);
            window.L.circleMarker(meLatLng, {
                radius: 10,
                color: '#2c2117',
                fillColor: '#cb6d4b',
                fillOpacity: 0.94,
                weight: 2,
            }).addTo(relationshipMap).bindTooltip(`我 · ${escapeHtml(meCity)}`, { permanent: true, direction: 'top', offset: [0, -10] });

            const distancePills = [];
            mappedItems.forEach(({ item, point }) => {
                const color = item.id === selected?.id ? '#a64f33' : '#2f8c7a';
                const targetLatLng = window.L.latLng(point.lat, point.lng);
                const distance = calculateDistanceKm(mePoint, point);
                bounds.extend(targetLatLng);
                window.L.circleMarker(targetLatLng, {
                    radius: item.id === selected?.id ? 9 : 7,
                    color,
                    fillColor: '#fff7ee',
                    fillOpacity: 0.95,
                    weight: 3,
                }).addTo(relationshipMap).bindTooltip(`${escapeHtml(item.name)} · ${escapeHtml(item.city || '')}`, { permanent: false });
                window.L.polyline([meLatLng, targetLatLng], {
                    color,
                    dashArray: '10 8',
                    weight: item.id === selected?.id ? 3.2 : 2.3,
                    opacity: 0.82,
                }).addTo(relationshipMap);
                const midpoint = window.L.latLng((mePoint.lat + point.lat) / 2, (mePoint.lng + point.lng) / 2);
                window.L.marker(midpoint, {
                    interactive: false,
                    icon: window.L.divIcon({
                        className: 'distance-label',
                        html: `<span>${formatDistanceKm(distance)}</span>`,
                    }),
                }).addTo(relationshipMap);
                distancePills.push({ name: item.name, distance });
            });

            relationshipMap.fitBounds(bounds.pad(0.22));
            setTimeout(() => {
                if (relationshipMap) relationshipMap.invalidateSize();
            }, 80);

            distancePills.sort((a, b) => a.distance - b.distance);
            if (pills) {
                pills.innerHTML = distancePills
                    .slice(0, 4)
                    .map((entry) => `<div class="distance-pill">${escapeHtml(entry.name)} · ${formatDistanceKm(entry.distance)}</div>`)
                    .join('');
            }
            if (meta) {
                meta.textContent = STANDALONE_STATIC_PREVIEW
                    ? `已定位 ${distancePills.length} 位联系人；当前是本地预览模式，地图底图已关闭，仅保留距离连线。`
                    : `已定位 ${distancePills.length} 位联系人；地图虚线代表“我”和每位联系人的城市距离。`;
            }
        }

        function scheduleRelationshipMap(items, selected) {
            clearTimeout(mapRenderTimer);
            if (!hasActiveSession() || state.ui.relationView !== 'graph' || state.ui.activePage !== 'relationships') {
                if (relationshipMap) {
                    relationshipMap.remove();
                    relationshipMap = null;
                }
                return;
            }
            mapRenderTimer = setTimeout(() => {
                renderRelationshipDistanceMap(items, selected);
            }, 40);
        }

        function buildLocalAssistantResponse(target, scenario, intent) {
            const needs = inferRelationshipNeeds(target);
            const budget = getGiftBudgetRecommendation(target, state.ui.giftOccasion);
            const opener = intent === '跟进'
                ? `${target.name}${target.type === 'mentor' ? '您好' : '，最近想跟你同步一下进展。'}`
                : intent === '安慰'
                    ? `${target.name}，看到你最近这段时间应该挺累的，我想先跟你说一声辛苦了。`
                    : intent === '邀约'
                        ? `${target.name}，最近如果你有空，我们找个轻松点的时间见一面吧。`
                        : intent === '送礼沟通'
                            ? `${target.name}，最近正好想到一个很适合你的小礼物，想先问问你最近有没有特别想添置的东西。`
                            : `${target.name}，最近想起你，就想来和你打个招呼。`;
            const secondLine = target.note
                ? `想到你最近提到的“${target.note.slice(0, 18)}${target.note.length > 18 ? '...' : ''}”，我也想顺着这个话题和你继续聊聊。`
                : '我不想只停留在一句泛泛的问候，所以也想多听听你最近的近况。';
            const closing = needs.vector.formal >= 72
                ? '如果你这周方便的话，我想找个合适的时间再和你认真聊一下。'
                : needs.vector.comfort >= 72
                    ? '不用急着回，等你方便的时候再聊就好。'
                    : '如果你最近方便，我们可以接着把这个话题展开一点。';
            return {
                id: `assistant-${Date.now()}`,
                targetId: target.id,
                intent,
                summary: `${target.name} 更偏 ${needs.dominant.join(' / ')}，这次回应适合温和、自然、带一点具体近况。`,
                reply: [opener, secondLine, scenario ? `另外我也记着你提到的这件事：${scenario}` : '', closing].filter(Boolean).join(' '),
                giftAdvice: `如果要送礼，更推荐围绕 ${needs.dominant.join(' / ')} 来选，避免只看价格不看感受。`,
                budgetText: `当前建议礼物价值：${budget.label}`,
                needs: needs.needs,
                source: 'local',
                createdAt: formatDate(new Date()),
            };
        }

        function escapeHtml(value) {
            return String(value ?? '')
                .replace(/&/g, '&amp;')
                .replace(/</g, '&lt;')
                .replace(/>/g, '&gt;')
                .replace(/"/g, '&quot;')
                .replace(/'/g, '&#39;');
        }

        function escapeAttribute(value) {
            return escapeHtml(value).replace(/`/g, '&#96;');
        }

        function showToast(message) {
            const toast = document.getElementById('toast');
            toast.textContent = message;
            toast.classList.add('show');
            clearTimeout(toastTimer);
            toastTimer = setTimeout(() => toast.classList.remove('show'), 2200);
        }

        function getUserInitial(name) {
            const value = String(name || '').trim();
            return value ? value.slice(0, 1) : '演';
        }

        function renderSessionChrome() {
            const user = getCurrentUser();
            const sidebarMode = document.getElementById('sidebar-mode-pill');
            const topbarStatus = document.getElementById('topbar-status-pill');
            const avatar = document.getElementById('session-avatar');
            const name = document.getElementById('session-user-name');
            const role = document.getElementById('session-user-role');
            const authToggle = document.getElementById('auth-toggle-btn');

            if (sidebarMode) {
                sidebarMode.textContent = user ? `欢迎回来 · ${user.name}` : 'V1.0.0';
            }
            if (topbarStatus) {
                topbarStatus.textContent = user ? `已登录 · ${authSession.remember ? '记住会话' : '临时会话'}` : '当前可用';
            }
            if (avatar) avatar.textContent = getUserInitial(user?.name);
            if (name) name.textContent = user?.name || '演示访客';
            if (role) role.textContent = user?.role || '网页体验账号';
            if (authToggle) authToggle.textContent = user ? '退出' : '登录';
        }

        function renderEntryState() {
            const mode = AUTH_MODES.includes(authState.ui.mode) ? authState.ui.mode : 'welcome';
            const active = hasActiveSession();
            const entryShell = document.getElementById('entry-shell');
            const appShell = document.getElementById('app-shell');
            const mobileNav = document.getElementById('mobile-nav');
            const welcomePane = document.getElementById('auth-pane-welcome');
            const authForm = document.getElementById('auth-form');
            const authTitle = document.getElementById('auth-title');
            const authCopy = document.getElementById('auth-copy');
            const authSubmit = document.getElementById('auth-submit-btn');
            const authFootnote = document.getElementById('auth-footnote');
            const authFeedback = document.getElementById('auth-feedback');
            const authNameField = document.getElementById('auth-name-field');
            const authPasswordField = document.getElementById('auth-password-field');
            const authRoleField = document.getElementById('auth-role-field');
            const authOtpField = document.getElementById('auth-otp-field');
            const authOtpHelp = document.getElementById('auth-otp-help');
            const authRegisterOtp = document.getElementById('auth-register-otp');
            const authIdentifier = document.getElementById('auth-identifier');
            const authRememberRow = document.getElementById('auth-remember-row');
            const authAltModeBtn = document.getElementById('auth-alt-mode-btn');
            const authForgotBtn = document.getElementById('auth-forgot-btn');
            const authResetLocalBtn = document.getElementById('auth-reset-local-btn');

            if (entryShell) {
                entryShell.classList.toggle('hidden', active);
                entryShell.setAttribute('aria-hidden', active ? 'true' : 'false');
            }
            if (appShell) {
                appShell.classList.toggle('locked', !active);
                clearTimeout(appRevealTimer);
                if (active) {
                    appRevealTimer = setTimeout(() => appShell.classList.add('ready'), 70);
                } else {
                    appShell.classList.remove('ready');
                }
            }
            if (mobileNav) mobileNav.classList.toggle('locked', !active);
            document.body.classList.toggle('entry-open', !active);

            ['welcome', 'login', 'register'].forEach((value) => {
                const tab = document.getElementById(`auth-tab-${value}`);
                if (tab) tab.classList.toggle('active', mode === value);
            });

            if (welcomePane) welcomePane.hidden = mode !== 'welcome';
            if (authForm) authForm.hidden = mode === 'welcome';
            if (authNameField) authNameField.hidden = mode !== 'register';
            if (authPasswordField) authPasswordField.hidden = mode === 'reset-request';
            if (authRoleField) authRoleField.hidden = mode !== 'register';
            if (authOtpField) authOtpField.hidden = true;
            if (authOtpHelp) authOtpHelp.hidden = true;
            if (authRememberRow) authRememberRow.hidden = mode === 'reset-request';

            if (mode === 'register') {
                if (authTitle) authTitle.textContent = '创建网页账号';
                if (authCopy) authCopy.textContent = '注册一个只保存在当前浏览器里的网页账号，方便你继续使用在线经营台。';
                if (authSubmit) authSubmit.textContent = '注册并进入';
                if (authFootnote) authFootnote.textContent = '注册成功后会直接进入网页版，不需要再次登录。';
                if (authRegisterOtp) {
                    authRegisterOtp.placeholder = localRegisterFlow
                        ? '请输入当前验证码'
                        : '先点创建获取验证码，再在这里输入';
                }
                if (authOtpHelp) {
                    authOtpHelp.textContent = localRegisterFlow
                        ? `当前为本地体验模式，不会真实发邮件。测试验证码：${localRegisterFlow.otp}`
                        : '当前为本地体验模式，不会真实发邮件。首次点击“创建并进入”后会生成测试验证码。';
                }
            } else if (mode === 'login') {
                if (authTitle) authTitle.textContent = '登录网页版';
                if (authCopy) authCopy.textContent = '如果你已经用过这个浏览器里的网页账号，可以直接登录继续上次的在线记录。';
                if (authSubmit) authSubmit.textContent = '登录并进入';
                if (authFootnote) authFootnote.textContent = '没有账号也没关系，先用网页版体验账号进入会更快。';
            } else if (mode === 'reset-request') {
                if (authTitle) authTitle.textContent = '找回密码';
                if (authCopy) authCopy.textContent = '输入注册时使用的邮箱或手机号，系统会给出网页端本地重置指引。';
                if (authSubmit) authSubmit.textContent = '发送重置指引';
                if (authFootnote) authFootnote.textContent = '当前为本地体验模式，不会真实发邮件，可根据提示重置网页端本地会话后重新注册。';
            } else {
                if (authTitle) authTitle.textContent = '进入网页版工作台';
                if (authCopy) authCopy.textContent = '网页端适合先体验、看结果、补重点关系；真正要直读微信时，再用桌面版。';
            }

            const conciseAuthContent = {
                welcome: {
                    title: '先看结果',
                    copy: '网页版先看报告、补资料、导出；直读微信本地库请用桌面版。',
                    submit: '进入网页版',
                    footnote: '网页版不负责直读微信本地库。',
                },
                login: {
                    title: '登录',
                    copy: '继续你的网页端记录。',
                    submit: '继续进入',
                    footnote: '没有账号也可以先体验。',
                },
                register: {
                    title: '注册',
                    copy: '账号只保存在当前浏览器。',
                    submit: '创建并进入',
                    footnote: '创建后会直接进入网页版。',
                },
            };
            const concise = conciseAuthContent[mode];
            if (concise) {
                if (authTitle) authTitle.textContent = concise.title;
                if (authCopy) authCopy.textContent = concise.copy;
                if (authSubmit) authSubmit.textContent = concise.submit;
                if (authFootnote) authFootnote.textContent = concise.footnote;
            }

            if (authAltModeBtn) {
                if (mode === 'login') {
                    authAltModeBtn.textContent = '没有账号？去注册';
                    authAltModeBtn.dataset.mode = 'register';
                } else if (mode === 'reset-request') {
                    authAltModeBtn.textContent = '返回登录';
                    authAltModeBtn.dataset.mode = 'login';
                } else {
                    authAltModeBtn.textContent = '已有账号？去登录';
                    authAltModeBtn.dataset.mode = 'login';
                }
            }
            if (authForgotBtn) authForgotBtn.hidden = mode !== 'login';
            if (authResetLocalBtn) authResetLocalBtn.hidden = mode === 'welcome';

            if (authFeedback) {
                authFeedback.textContent = authState.ui.feedback || '';
                authFeedback.classList.toggle('success', authState.ui.feedbackType === 'success');
            }
            if (authIdentifier && authState.ui.lastIdentifier && !authIdentifier.value) {
                authIdentifier.value = authState.ui.lastIdentifier;
            }

            renderLocalRegisterVerificationPanel(mode);
            renderSessionChrome();
        }

        function setAuthMode(mode) {
            authState.ui.mode = AUTH_MODES.includes(mode) ? mode : 'welcome';
            authState.ui.feedback = '';
            authState.ui.feedbackType = '';
            persistAuthState();
            renderEntryState();
        }

        function beginSession(user, remember) {
            authSession = {
                currentUserId: user.id,
                remember: Boolean(remember),
            };
            authState.ui.feedback = '';
            authState.ui.feedbackType = '';
            authState.ui.lastIdentifier = user.identifier || '';
            if (!state.profile.name || state.profile.name === defaultState.profile.name || state.profile.name === '演示访客') {
                state.profile.name = user.name;
            }
            if (user.role && (!state.profile.title || state.profile.title === defaultState.profile.title)) {
                state.profile.title = user.role;
            }
            state.ui.activePage = 'dashboard';
            persistAuthSession();
            persistAuthState();
            renderAll();
            syncHashToPage();
            renderEntryState();
            showToast(`欢迎回来，${user.name}`);
        }

        function logout() {
            authSession = cloneData(defaultAuthSession);
            authState.ui.mode = 'welcome';
            authState.ui.feedback = '';
            authState.ui.feedbackType = '';
            persistAuthSession();
            persistAuthState();
            if (relationshipMap) {
                relationshipMap.remove();
                relationshipMap = null;
            }
            renderAll();
            renderEntryState();
            showToast('已退出当前会话');
        }

        function enterDemoAccount() {
            const demo = authState.users.find((item) => item.identifier === 'demo@renmai.app');
            if (!demo) return;
            beginSession(demo, true);
        }

        function resetLocalAuthSession() {
            const keysToRemove = [
                AUTH_STORAGE_KEY,
                AUTH_SESSION_KEY,
                PUBLIC_AUTH_FLOW_STORAGE_KEY,
                LOCAL_REGISTER_FLOW_KEY,
            ];
            try {
                keysToRemove.forEach((key) => {
                    localStorage.removeItem(key);
                    sessionStorage.removeItem(key);
                });
                Object.keys(localStorage).forEach((key) => {
                    if (String(key).startsWith('sb-') && String(key).endsWith('-auth-token')) {
                        localStorage.removeItem(key);
                    }
                });
            } catch (_) {
                // ignore
            }

            authState = cloneData(defaultAuthState);
            authSession = cloneData(defaultAuthSession);
            clearLocalRegisterFlow();
            authState.ui.mode = 'welcome';
            authState.ui.feedback = '已重置本地会话，请重新选择注册或登录。';
            authState.ui.feedbackType = 'success';
            persistAuthState();
            persistAuthSession();
            renderAll();
            renderEntryState();
        }

        function submitAuthForm(event) {
            event.preventDefault();
            const form = new FormData(event.target);
            const mode = authState.ui.mode;
            const identifier = String(form.get('identifier') || '').trim();
            const password = String(form.get('password') || '').trim();
            const remember = form.get('remember') !== null;
            const normalizedIdentifier = identifier.toLowerCase();
            authState.ui.lastIdentifier = identifier;

            if (mode === 'reset-request') {
                if (!identifier) {
                    authState.ui.feedback = '请先填写注册时使用的邮箱或手机号。';
                    authState.ui.feedbackType = '';
                    persistAuthState();
                    renderEntryState();
                    return;
                }
                authState.ui.feedback = '当前为本地体验模式，系统未真实发送邮件。可点击“重置本地会话”后重新注册，或直接返回登录已有账号。';
                authState.ui.feedbackType = 'success';
                persistAuthState();
                renderEntryState();
                return;
            }

            if (!identifier || !password) {
                authState.ui.feedback = '请先填写账号和密码。';
                authState.ui.feedbackType = '';
                persistAuthState();
                renderEntryState();
                return;
            }

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
                if (authState.users.some((item) => String(item.identifier || '').toLowerCase() === normalizedIdentifier)) {
                    authState.ui.feedback = '这个账号已经存在，直接登录就可以。';
                    authState.ui.feedbackType = '';
                    persistAuthState();
                    renderEntryState();
                    return;
                }
                clearLocalRegisterFlow();
                const user = {
                    id: `auth-${Date.now()}`,
                    name: displayName,
                    identifier,
                    password,
                    role: role || '本地用户',
                };
                authState.users.unshift(user);
                persistAuthState();
                beginSession(user, remember);
                return;
            }

            const user = authState.users.find((item) => String(item.identifier || '').toLowerCase() === normalizedIdentifier);
            if (!user || user.password !== password) {
                authState.ui.feedback = '账号或密码不正确，可以先用网页版体验账号进入。';
                authState.ui.feedbackType = '';
                persistAuthState();
                renderEntryState();
                return;
            }
            beginSession(user, remember);
        }

        function getPageFromHash() {
            if (typeof window === 'undefined' || !window.location) return null;
            const hash = String(window.location.hash || '').replace(/^#/, '').trim().toLowerCase();
            return AVAILABLE_PAGES.includes(hash) ? hash : null;
        }

        function applyHashPage() {
            const hashPage = getPageFromHash();
            if (hashPage) {
                state.ui.activePage = hashPage;
                return;
            }
            if (!AVAILABLE_PAGES.includes(state.ui.activePage)) {
                state.ui.activePage = 'dashboard';
            }
        }

        function syncHashToPage() {
            if (typeof window === 'undefined' || !window.location) return;
            const nextHash = `#${state.ui.activePage}`;
            if (window.location.hash === nextHash) return;
            if (typeof history !== 'undefined' && history && typeof history.replaceState === 'function') {
                history.replaceState(null, '', nextHash);
                return;
            }
            window.location.hash = nextHash;
        }

        function syncSelection() {
            if (!state.relationships.some((item) => item.id === state.ui.selectedRelationshipId)) {
                state.ui.selectedRelationshipId = state.relationships[0]?.id || null;
            }
            if (!state.relationships.some((item) => item.id === state.ui.selectedMessageRelationshipId)) {
                state.ui.selectedMessageRelationshipId = state.relationships[0]?.id || null;
            }
            if (!state.analyses.some((item) => item.id === state.ui.selectedAnalysisId)) {
                state.ui.selectedAnalysisId = state.analyses[0]?.id || null;
            }
            if (!state.relationships.some((item) => item.id === state.ui.selectedGiftRelationshipId)) {
                state.ui.selectedGiftRelationshipId = state.relationships[0]?.id || null;
            }
            if (!state.relationships.some((item) => item.id === state.ui.assistantTargetId)) {
                state.ui.assistantTargetId = state.relationships[0]?.id || null;
            }
        }

        function renderPageByName(page) {
            switch (page) {
                case 'relationships':
                    renderRelationships();
                    break;
                case 'messages':
                    renderMessages();
                    break;
                case 'analysis':
                    renderAnalysis();
                    break;
                case 'gifts':
                    renderGifts();
                    break;
                case 'profile':
                    renderProfile();
                    break;
                case 'dashboard':
                default:
                    renderDashboard();
                    break;
            }
        }

        function renderAll() {
            applyWebExperiencePreferences();
            syncSelection();
            renderNavigation();
            renderPageByName(state.ui.activePage);
            persistState();
            renderEntryState();
        }

        function renderActivePage() {
            renderWorkspaceBrief();
            renderPageByName(state.ui.activePage);
            renderEntryState();
        }

        function syncTopbarMotionNav(targetPage = state.ui.activePage) {
            const shell = document.getElementById('topbar-page-nav');
            if (!shell) return;
            const pill = shell.querySelector('.topbar-nav-pill');
            if (!pill) return;
            const normalized = AVAILABLE_PAGES.includes(targetPage) ? targetPage : state.ui.activePage;
            const activeItem = shell.querySelector(`.motion-nav-item[data-nav="${normalized}"]`);
            const shellStyle = typeof window !== 'undefined' && typeof window.getComputedStyle === 'function'
                ? window.getComputedStyle(shell)
                : null;
            if (!activeItem || shellStyle?.display === 'none' || shell.offsetParent === null) {
                shell.classList.remove('is-ready');
                return;
            }
            const shellRect = shell.getBoundingClientRect();
            const itemRect = activeItem.getBoundingClientRect();
            const nextX = Math.max(0, itemRect.left - shellRect.left);
            const nextWidth = Math.max(64, itemRect.width);
            shell.style.setProperty('--topbar-nav-pill-x', `${nextX.toFixed(2)}px`);
            shell.style.setProperty('--topbar-nav-pill-width', `${nextWidth.toFixed(2)}px`);
            shell.classList.add('is-ready');
        }

        function scheduleTopbarMotionNavSync(targetPage = state.ui.activePage) {
            if (topbarMotionFrame && typeof cancelAnimationFrame === 'function') {
                cancelAnimationFrame(topbarMotionFrame);
            }
            const run = () => {
                topbarMotionFrame = null;
                syncTopbarMotionNav(targetPage);
            };
            if (typeof requestAnimationFrame === 'function') {
                topbarMotionFrame = requestAnimationFrame(run);
                return;
            }
            setTimeout(run, 16);
        }

        function bindTopbarMotionNav() {
            const shell = document.getElementById('topbar-page-nav');
            if (!shell || shell.dataset.bound === 'true') return;
            shell.dataset.bound = 'true';
            const restoreActive = () => {
                scheduleTopbarMotionNavSync(state.ui.activePage);
            };
            shell.addEventListener('pointerover', (event) => {
                const item = event.target.closest('.motion-nav-item');
                if (!item || !shell.contains(item)) return;
                scheduleTopbarMotionNavSync(item.dataset.nav || state.ui.activePage);
            });
            shell.addEventListener('focusin', (event) => {
                const item = event.target.closest('.motion-nav-item');
                if (!item || !shell.contains(item)) return;
                scheduleTopbarMotionNavSync(item.dataset.nav || state.ui.activePage);
            });
            shell.addEventListener('pointerleave', restoreActive);
            shell.addEventListener('focusout', () => {
                const reset = () => {
                    if (!shell.contains(document.activeElement)) {
                        restoreActive();
                    }
                };
                if (typeof requestAnimationFrame === 'function') {
                    requestAnimationFrame(reset);
                    return;
                }
                setTimeout(reset, 0);
            });
        }

        function renderNavigation() {
            const activePage = state.ui.activePage;
            document.querySelectorAll('[data-nav]').forEach((item) => {
                item.classList.toggle('active', item.dataset.nav === activePage);
            });
            document.querySelectorAll('.page').forEach((page) => {
                page.classList.toggle('active', page.id === `page-${activePage}`);
            });
            document.getElementById('page-title').textContent = PAGE_TITLES[activePage];
            document.getElementById('page-meta').textContent = PAGE_META[activePage];
            renderSessionChrome();
            renderWorkspaceBrief();
            syncHashToPage();
            scheduleTopbarMotionNavSync(activePage);
        }

        function getFilteredRelationships() {
            const keyword = state.ui.relationSearch.trim().toLowerCase();
            return state.relationships.filter((item) => {
                const matchType = state.ui.relationFilter === 'all' || item.type === state.ui.relationFilter;
                const haystack = [
                    item.name,
                    item.note,
                    item.city,
                    ...(item.tags || []),
                    RELATION_LABELS[item.type],
                    item.portraitProfile?.summary || '',
                    ...(item.portraitProfile?.styleTags || []),
                ].join(' ').toLowerCase();
                return matchType && (!keyword || haystack.includes(keyword));
            });
        }

        function getVisibleRelationships(relationships, selected) {
            const minimum = RELATIONSHIP_RENDER_BATCH;
            let visibleCount = Math.max(minimum, Number(state.ui.relationVisibleCount || minimum));
            const selectedIndex = selected
                ? relationships.findIndex((item) => item.id === selected.id)
                : -1;
            if (selectedIndex >= visibleCount) {
                visibleCount = selectedIndex + 1;
            }
            const visible = relationships.slice(0, visibleCount);
            return {
                visible,
                visibleCount,
                remainingCount: Math.max(0, relationships.length - visible.length),
            };
        }

        function getVisibleAnalysisReports(reports, selected) {
            const minimum = ANALYSIS_RENDER_BATCH;
            let visibleCount = Math.max(minimum, Number(state.ui.analysisVisibleCount || minimum));
            const selectedIndex = selected
                ? reports.findIndex((item) => item.id === selected.id)
                : -1;
            if (selectedIndex >= visibleCount) {
                visibleCount = selectedIndex + 1;
            }
            const visible = reports.slice(0, visibleCount);
            return {
                visible,
                visibleCount,
                remainingCount: Math.max(0, reports.length - visible.length),
            };
        }

        function getVisibleMessageThreads(threads, selected) {
            const minimum = MESSAGE_THREAD_RENDER_BATCH;
            let visibleCount = Math.max(minimum, Number(state.ui.messageThreadVisibleCount || minimum));
            const selectedIndex = selected
                ? threads.findIndex((item) => item.relationship.id === selected.id)
                : -1;
            if (selectedIndex >= visibleCount) {
                visibleCount = selectedIndex + 1;
            }
            const visible = threads.slice(0, visibleCount);
            return {
                visible,
                visibleCount,
                remainingCount: Math.max(0, threads.length - visible.length),
            };
        }

        function getFilteredGifts() {
            const selectedRelationship = getSelectedGiftRelationship();
            return GIFT_CATALOG
                .filter((item) => {
                    return item.relationTypes.includes(state.ui.giftRelation)
                        && item.occasion.includes(state.ui.giftOccasion)
                        && item.price <= state.ui.giftBudget;
                })
                .map((item) => {
                    const score = selectedRelationship
                        ? scoreGiftForRelationship(item, selectedRelationship, state.ui.giftOccasion)
                        : 58 + (item.occasion.includes(state.ui.giftOccasion) ? 10 : 0);
                    return {
                        ...item,
                        matchScore: score,
                    };
                })
                .sort((a, b) => b.matchScore - a.matchScore || a.price - b.price);
        }

        function getUpcomingBirthdays() {
            if (!state.settings.birthdayReminder) return [];
            return state.relationships
                .filter((item) => item.birthday)
                .map((item) => ({ ...item, days: daysUntilBirthday(item.birthday) }))
                .sort((a, b) => a.days - b.days);
        }
        function closeRelationshipModal() {
            document.getElementById('relationship-modal').classList.remove('open');
            document.getElementById('relationship-modal').setAttribute('aria-hidden', 'true');
        }

        function deleteRelationship(id) {
            const relationship = state.relationships.find((item) => item.id === id);
            if (!relationship || !window.confirm(`确定删除 ${relationship.name} 吗？`)) return;
            state.relationships = state.relationships.filter((item) => item.id !== id);
            if (portraitReviewState.candidate?.relationshipId === id) {
                portraitReviewState.candidate = null;
                portraitReviewState.pendingPage = null;
                portraitReviewState.analyzing = false;
            }
            renderAll();
            showToast(`${relationship.name} 已删除`);
        }

        function updateRelationshipImportanceRankVisibility() {
            const tier = document.getElementById('relationship-importance-tier')?.value || 'regular';
            const rankRow = document.getElementById('relationship-importance-rank-row');
            if (rankRow) rankRow.hidden = tier !== 'important';
        }

        function getFocusTargets() {
            return state.relationships
                .map((item) => {
                    const birthdayScore = item.birthday ? Math.max(0, 22 - daysUntilBirthday(item.birthday)) : 0;
                    const cadenceGap = getCadenceGap(item);
                    const depthGap = getDepthGap(item);
                    const importanceBonus = item.importanceTier === 'important'
                        ? 26 + (6 - getImportanceRank(item)) * 8
                        : 0;
                    const score = cadenceGap * 18 + depthGap * 10 + birthdayScore + importanceBonus;
                    let levelLabel = '节奏稳定';
                    let levelClass = '';
                    if (birthdayScore >= 14) {
                        levelLabel = '生日临近';
                        levelClass = 'warn';
                    } else if (item.importanceTier === 'important' && getImportanceRank(item) <= 2) {
                        levelLabel = `重要层级 · 第 ${getImportanceRank(item)} 顺位`;
                        levelClass = 'danger';
                    } else if (cadenceGap >= 2 || depthGap >= 2) {
                        levelLabel = '建议优先互动';
                        levelClass = 'danger';
                    } else if (item.importanceTier === 'important') {
                        levelLabel = '重要关系';
                        levelClass = 'warn';
                    }
                    return {
                        ...item,
                        score,
                        levelLabel,
                        levelClass,
                        note: item.note || `当前每周交流 ${item.weeklyFrequency} 次，每月深聊 ${item.monthlyDepth} 次。`,
                    };
                })
                .sort((a, b) => {
                    if (b.score !== a.score) return b.score - a.score;
                    if (a.importanceTier !== b.importanceTier) return a.importanceTier === 'important' ? -1 : 1;
                    return getImportanceRank(a) - getImportanceRank(b);
                });
        }

        function getRelationshipRiskCount() {
            return state.relationships.filter((item) => {
                const birthdayDays = daysUntilBirthday(item.birthday);
                return getCadenceGap(item) >= 2
                    || getDepthGap(item) >= 2
                    || (typeof birthdayDays === 'number' && birthdayDays >= 0 && birthdayDays <= 7);
            }).length;
        }

        function formatShareLabel(count, total) {
            if (!total) return '0%';
            return `${Math.round((count / total) * 100)}%`;
        }

        function getNextJourneyPage(page) {
            const currentIndex = JOURNEY_FLOW.indexOf(page);
            if (currentIndex === -1) return null;
            return JOURNEY_FLOW[currentIndex + 1] || null;
        }

        function getWorkspaceBriefData(page = state.ui.activePage) {
            const relationships = state.relationships;
            const focusTargets = getFocusTargets();
            const upcomingBirthdays = getUpcomingBirthdays();
            const latestReport = state.analyses[0] || null;
            const bridge = normalizeBridge(state.bridge || {});
            const importantRelationships = relationships.filter((item) => item.importanceTier === 'important');
            const onTrackCount = relationships.filter((item) => getCadenceGap(item) === 0).length;
            const deepReadyCount = relationships.filter((item) => getDepthGap(item) === 0).length;
            const coveredImportantCount = importantRelationships.filter((item) => getCadenceGap(item) === 0 && getDepthGap(item) <= 1).length;

            return {
                page,
                totalRelationships: relationships.length,
                focusTarget: focusTargets[0] || null,
                focusTargets: focusTargets.slice(0, 3),
                nextBirthday: upcomingBirthdays[0] || null,
                latestReport,
                bridge,
                onTrackCount,
                deepReadyCount,
                importantCount: importantRelationships.length,
                coveredImportantCount,
                riskCount: getRelationshipRiskCount(),
                nextJourneyPage: getNextJourneyPage(page),
            };
        }

        function renderWorkspaceBrief() {
            const host = document.getElementById('workspace-brief-shell');
            if (!host) return;

            const data = getWorkspaceBriefData();
            const focusLabel = data.focusTarget
                ? `${data.focusTarget.name} · ${data.focusTarget.levelLabel}`
                : '先补一位关系对象';
            const focusCopy = data.focusTarget
                ? `${data.focusTarget.note} 建议先看关系判断，再决定要不要继续写消息。`
                : '当前还没有明确重点对象。先新增联系人，或接收桌面交接包把结果带进来。';
            const reportLabel = data.latestReport
                ? `${data.latestReport.title} · ${data.latestReport.score} 分`
                : '还没有生成报告';
            const reportCopy = data.latestReport
                ? data.latestReport.summary
                : data.totalRelationships
                    ? '可以先生成一份全局报告，把风险点和下一步动作集中看完。'
                    : '先补充基础关系，再生成报告会更有意义。';
            const sourceLabel = data.bridge.source === 'desktop' ? '桌面桥接包' : '浏览器本地';
            const sourceCopy = data.bridge.source === 'desktop'
                ? `${data.bridge.contactCount} 位联系人 · ${data.bridge.recordCount} 条摘要消息`
                : '当前这份工作台还只保存在浏览器。';
            const birthdayLabel = data.nextBirthday ? `${data.nextBirthday.name} · ${data.nextBirthday.birthday}` : '最近没有生日提醒';
            const birthdayCopy = data.nextBirthday
                ? `${data.nextBirthday.days === 0 ? '今天' : `${data.nextBirthday.days} 天后`}，可以提前准备互动或礼物。`
                : '生日提醒会在你补全生日字段后自动出现。';
            const recommendation = data.totalRelationships
                ? data.riskCount
                    ? `当前有 ${data.riskCount} 段关系需要优先处理，先别把时间分散。`
                    : '当前节奏整体稳定，可以先补细节或继续消息。'
                : '先导入或新增基础关系，网页端才会真正开始给出判断。';

            const actions = [];
            if (data.focusTarget) {
                actions.push(`<button class="solid-btn" data-action="open-focus-relationship" data-id="${escapeAttribute(data.focusTarget.id)}" type="button">看 ${escapeHtml(data.focusTarget.name)}</button>`);
                actions.push(`<button class="ghost-btn" data-action="open-focus-message" data-id="${escapeAttribute(data.focusTarget.id)}" type="button">继续消息</button>`);
            } else {
                actions.push('<button class="solid-btn" data-action="open-add-modal" type="button">新增关系</button>');
            }
            if (data.latestReport) {
                actions.push('<button class="ghost-btn" data-nav="analysis" type="button">读最新报告</button>');
            } else if (data.totalRelationships) {
                actions.push('<button class="ghost-btn" data-action="generate-analysis" data-target-id="all" type="button">生成全局报告</button>');
            }
            if (data.nextJourneyPage) {
                actions.push(`<button class="chip-btn" data-nav="${escapeAttribute(data.nextJourneyPage)}" type="button">下一站：${escapeHtml(PAGE_TITLES[data.nextJourneyPage])}</button>`);
            }
            actions.push(
                data.bridge.source === 'desktop'
                    ? '<button class="chip-btn" data-action="open-handoff-modal" type="button">看交接状态</button>'
                    : '<button class="chip-btn" data-action="import-data" type="button">接收交接包</button>',
            );

            const markup = `
                <section class="panel workspace-brief">
                    <div class="workspace-brief-head">
                        <div>
                            <div class="workspace-brief-kicker">当前工作摘要</div>
                            <h3 class="workspace-brief-title">${escapeHtml(PAGE_TITLES[data.page])}：${escapeHtml(recommendation)}</h3>
                            <p class="workspace-brief-copy">${escapeHtml(PAGE_META[data.page])}</p>
                        </div>
                        <div class="workspace-brief-badge-row">
                            <div class="badge">${data.totalRelationships ? `${data.totalRelationships} 位联系人` : '还未开始'}</div>
                            <div class="badge ${data.riskCount ? 'warn' : ''}">${data.riskCount ? `${data.riskCount} 个优先处理` : '节奏稳定'}</div>
                        </div>
                    </div>
                    <div class="workspace-brief-grid">
                        <article class="workspace-brief-card workspace-brief-card-focus">
                            <span class="workspace-brief-label">当前重点对象</span>
                            <strong>${escapeHtml(focusLabel)}</strong>
                            <p>${escapeHtml(focusCopy)}</p>
                        </article>
                        <article class="workspace-brief-card">
                            <span class="workspace-brief-label">最近报告</span>
                            <strong>${escapeHtml(reportLabel)}</strong>
                            <p>${escapeHtml(reportCopy)}</p>
                        </article>
                        <article class="workspace-brief-card">
                            <span class="workspace-brief-label">提醒与节奏</span>
                            <strong>${escapeHtml(birthdayLabel)}</strong>
                            <p>${escapeHtml(birthdayCopy)}</p>
                        </article>
                        <article class="workspace-brief-card">
                            <span class="workspace-brief-label">当前数据来源</span>
                            <strong>${escapeHtml(sourceLabel)}</strong>
                            <p>${escapeHtml(sourceCopy)}</p>
                        </article>
                    </div>
                    <div class="workspace-brief-actions">
                        ${actions.join('')}
                    </div>
                </section>
            `;

            if (host.innerHTML === markup) return;
            host.innerHTML = markup;
        }

        function renderDashboardRadarSection() {
            const data = getWorkspaceBriefData('dashboard');
            const pulseItems = [
                {
                    label: '节奏稳定率',
                    value: formatShareLabel(data.onTrackCount, data.totalRelationships),
                    percent: data.totalRelationships ? Math.round((data.onTrackCount / data.totalRelationships) * 100) : 0,
                    meta: data.totalRelationships ? `${data.onTrackCount} / ${data.totalRelationships} 位联系人达到建议交流频率` : '先新增或导入联系人后，系统会开始判断节奏。',
                },
                {
                    label: '深聊覆盖',
                    value: formatShareLabel(data.deepReadyCount, data.totalRelationships),
                    percent: data.totalRelationships ? Math.round((data.deepReadyCount / data.totalRelationships) * 100) : 0,
                    meta: data.totalRelationships ? `${data.deepReadyCount} 位联系人已达到建议深聊密度` : '没有关系数据时，暂时不会显示深聊判断。',
                },
                {
                    label: '重要关系照看',
                    value: data.importantCount ? formatShareLabel(data.coveredImportantCount, data.importantCount) : '未设置',
                    percent: data.importantCount ? Math.round((data.coveredImportantCount / data.importantCount) * 100) : 0,
                    meta: data.importantCount ? `${data.coveredImportantCount} / ${data.importantCount} 位重要关系处在较稳状态` : '先在联系人页标记“重要关系”，这里才会更有参考价值。',
                },
            ];
            const insightItems = [
                {
                    label: '最值得先看的对象',
                    value: data.focusTarget
                        ? `${data.focusTarget.name} · ${data.focusTarget.levelLabel}`
                        : '先新增联系人或接收桌面交接包',
                },
                {
                    label: '最近报告',
                    value: data.latestReport
                        ? `${data.latestReport.title} · ${data.latestReport.score} 分`
                        : '还没有报告，建议先生成一份全局报告',
                },
                {
                    label: '当前数据来源',
                    value: data.bridge.source === 'desktop'
                        ? `桌面桥接包 · ${data.bridge.contactCount} 位联系人`
                        : '浏览器本地数据',
                },
            ];
            const summaryTitle = data.focusTarget
                ? `今天先把 ${data.focusTarget.name} 这段关系判断清楚`
                : '今天先把基础关系数据铺起来';
            const summaryCopy = data.focusTarget
                ? `${data.focusTarget.note} 先确认关系页里的理由，再决定要不要继续补消息、报告或礼物建议。`
                : '当前还没有明确的重点对象。你可以先新增联系人，或者接收桌面交接包，让网页端先把优先级整理出来。';
            const primaryAction = data.focusTarget
                ? `<button class="solid-btn" data-action="open-focus-relationship" data-id="${escapeAttribute(data.focusTarget.id)}" type="button">看 ${escapeHtml(data.focusTarget.name)}</button>`
                : '<button class="solid-btn" data-action="open-add-modal" type="button">新增关系</button>';
            const secondaryAction = data.focusTarget
                ? `<button class="ghost-btn" data-action="open-focus-message" data-id="${escapeAttribute(data.focusTarget.id)}" type="button">继续消息</button>`
                : '<button class="ghost-btn" data-action="import-data" type="button">接收交接包</button>';

            return `
                <section class="panel panel-body dashboard-radar-panel">
                    <div class="panel-header">
                        <div>
                            <h3 class="panel-title">经营雷达</h3>
                            <p class="panel-subtitle">先判断节奏、深聊和重要关系覆盖，再决定今天要不要补消息、补资料或直接生成报告。</p>
                        </div>
                        <div class="badge ${data.riskCount ? 'warn' : ''}">${data.riskCount ? `${data.riskCount} 个关系需要优先处理` : '当前节奏整体稳定'}</div>
                    </div>
                    <div class="dashboard-radar-grid">
                        <div class="dashboard-pulse-grid">
                            ${pulseItems.map((item) => `
                                <article class="dashboard-pulse-card">
                                    <div class="dashboard-pulse-row">
                                        <strong>${escapeHtml(item.label)}</strong>
                                        <span>${escapeHtml(item.value)}</span>
                                    </div>
                                    <div class="dashboard-pulse-meter">
                                        <div class="dashboard-pulse-fill" style="width:${item.percent}%;"></div>
                                    </div>
                                    <div class="dashboard-pulse-meta">${escapeHtml(item.meta)}</div>
                                </article>
                            `).join('')}
                        </div>
                        <article class="dashboard-radar-summary">
                            <div class="next-action-kicker">今天建议</div>
                            <h4>${escapeHtml(summaryTitle)}</h4>
                            <p>${escapeHtml(summaryCopy)}</p>
                            <div class="dashboard-insight-list">
                                ${insightItems.map((item) => `
                                    <div class="dashboard-insight-item">
                                        <strong>${escapeHtml(item.label)}</strong>
                                        <span>${escapeHtml(item.value)}</span>
                                    </div>
                                `).join('')}
                            </div>
                            <div class="detail-actions">
                                ${primaryAction}
                                ${secondaryAction}
                                <button class="chip-btn" data-nav="analysis" type="button">去看报告</button>
                            </div>
                        </article>
                    </div>
                </section>
            `;
        }

        function buildPersonalityProfile() {
            const relationships = state.relationships;
            const total = relationships.length || 1;
            const avgIntimacy = relationships.reduce((sum, item) => sum + item.intimacy, 0) / total;
            const diversity = Object.keys(groupByType(relationships)).length;
            const onTrackRatio = relationships.filter((item) => getCadenceGap(item) === 0).length / total;
            const deepRatio = relationships.filter((item) => getDepthGap(item) === 0).length / total;
            const importantRatio = relationships.filter((item) => item.importanceTier === 'important').length / total;

            return {
                traits: [
                    { name: '开放度', score: clamp(Math.round(48 + diversity * 7 + onTrackRatio * 10), 40, 92), color: 'linear-gradient(90deg, #cb6d4b, #de9b60)', description: '你愿意在不同圈层之间保持连接，整体关系结构比较丰富。' },
                    { name: '尽责度', score: clamp(Math.round(50 + onTrackRatio * 24 + deepRatio * 8), 38, 95), color: 'linear-gradient(90deg, #2f8c7a, #57a58b)', description: '你会把关系经营成一件持续推进的事，而不是完全随缘。' },
                    { name: '外向度', score: clamp(Math.round(44 + relationships.reduce((sum, item) => sum + item.weeklyFrequency, 0) / total * 4), 42, 88), color: 'linear-gradient(90deg, #d8a53b, #e1bf70)', description: '从互动频率来看，你更习惯通过持续交流维持关系热度。' },
                    { name: '宜人度', score: clamp(Math.round(54 + avgIntimacy * 0.3), 45, 93), color: 'linear-gradient(90deg, #2c2117, #7d6856)', description: '你的关系维护里带着明显的陪伴感和稳定感。' },
                    { name: '稳定度', score: clamp(Math.round(58 + deepRatio * 18 + importantRatio * 10), 40, 90), color: 'linear-gradient(90deg, #a64f33, #cb6d4b)', description: '你会对重要对象投入更多稳定关注，不容易完全掉线。' },
                ],
            };
        }

        function renderFocusCard(item) {
            const birthdayDays = daysUntilBirthday(item.birthday);
            const noteSegments = [item.note];
            if (typeof birthdayDays === 'number' && birthdayDays >= 0 && birthdayDays <= 14) {
                noteSegments.push(birthdayDays === 0 ? '今天生日，适合立刻安排触点。' : `${birthdayDays} 天后生日，可以提前准备互动或礼物。`);
            }

            return `
                <div class="focus-card">
                    <div class="focus-head">
                        <div>
                            <h4>${escapeHtml(item.name)}</h4>
                            <p class="analysis-summary">${escapeHtml(`${getImportanceDisplay(item)} · 每周 ${item.weeklyFrequency} 次交流 · 每月 ${item.monthlyDepth} 次深聊`)}</p>
                        </div>
                        <div class="badge ${item.levelClass}">${escapeHtml(item.levelLabel)}</div>
                    </div>
                    <p class="focus-note">${escapeHtml(noteSegments.filter(Boolean).join(' '))}</p>
                    <div class="focus-meta-row">
                        <span class="tag">${escapeHtml(RELATION_LABELS[item.type] || '关系对象')}</span>
                        <span class="tag">${escapeHtml(intimacyLevel(item.intimacy))}</span>
                    </div>
                    <div class="focus-actions">
                        <button class="ghost-btn" data-action="open-focus-relationship" data-id="${escapeAttribute(item.id)}" type="button">看关系</button>
                        <button class="ghost-btn" data-action="open-focus-message" data-id="${escapeAttribute(item.id)}" type="button">去消息</button>
                        <button class="chip-btn" data-action="jump-to-gifts" data-id="${escapeAttribute(item.id)}" type="button">看礼物</button>
                    </div>
                </div>
            `;
        }

        function renderWebGuideSection() {
            if (state.settings.webGuideDismissed) return '';
            return `
                <section class="panel panel-body">
                    <div class="panel-header">
                        <div>
                            <h3 class="panel-title">新手先看这 3 件事</h3>
                            <p class="panel-subtitle">先按这 3 步走，网页端会更好理解；真正要直读微信时，再切桌面版。</p>
                        </div>
                        <div class="detail-actions">
                            <div class="badge">仅供参考</div>
                            <button class="chip-btn" data-action="dismiss-web-guide" type="button">知道了</button>
                        </div>
                    </div>
                    <div class="web-guide-grid">
                        <article class="guide-card">
                            <div class="guide-step">1</div>
                            <h4>先看总览</h4>
                            <p>先看左侧“总览”和右上角的最新报告，知道今天先处理谁。</p>
                            <div class="detail-actions">
                                <button class="ghost-btn" data-nav="dashboard" type="button">留在总览</button>
                            </div>
                        </article>
                        <article class="guide-card">
                            <div class="guide-step">2</div>
                            <h4>再点联系人</h4>
                            <p>进入联系人页，看分数、理由和建议。这里更适合补信息和找重点对象。</p>
                            <div class="detail-actions">
                                <button class="ghost-btn" data-nav="relationships" type="button">去联系人</button>
                            </div>
                        </article>
                        <article class="guide-card">
                            <div class="guide-step">3</div>
                            <h4>要直读去桌面版</h4>
                            <p>网页版不直读微信本地库，只适合看结果、补资料、导出和在线体验。直读、扫描导出、处理原始附件请用桌面版。</p>
                            <div class="detail-actions">
                                <button class="ghost-btn" data-nav="analysis" type="button">先看报告</button>
                            </div>
                        </article>
                    </div>
                    <div class="web-diff-grid">
                        <div class="web-diff-item">
                            <strong>网页版</strong>
                            <p>先看报告、补关系、导出数据、做在线体验。</p>
                        </div>
                        <div class="web-diff-item">
                            <strong>桌面版</strong>
                            <p>直读微信本地库、处理导出文件、管理原始聊天数据。</p>
                        </div>
                    </div>
                </section>
            `;
        }

        function renderWebDisplaySettingsSection() {
            const themeMarkup = Object.entries(WEB_THEME_PRESETS)
                .map(([key, preset]) => `
                    <button class="web-toggle ${sanitizeWebTheme(state.settings.webTheme) === key ? 'active' : ''}" data-action="set-web-theme" data-theme="${key}" type="button">
                        ${escapeHtml(preset.label)}
                    </button>
                `)
                .join('');
            const densityMarkup = Object.entries(WEB_DENSITY_LABELS)
                .map(([key, label]) => `
                    <button class="web-toggle ${sanitizeWebDensity(state.settings.webDensity) === key ? 'active' : ''}" data-action="set-web-density" data-density="${key}" type="button">
                        ${escapeHtml(label)}
                    </button>
                `)
                .join('');

            return `
                <section class="panel panel-body">
                    <div class="panel-header">
                        <div>
                            <h3 class="panel-title">显示设置</h3>
                            <p class="panel-subtitle">主题和密度会保存到当前浏览器，刷新后也会保留。</p>
                        </div>
                        <div class="detail-actions">
                            <div class="badge">已保存本地</div>
                            ${renderJourneyReopenButton()}
                            <button class="chip-btn" data-action="reopen-web-guide" type="button">重新看引导</button>
                        </div>
                    </div>
                    <div class="web-setting-block">
                        <div class="web-toggle-label">主题</div>
                        <div class="web-toggle-row">${themeMarkup}</div>
                        <div class="web-toggle-label" style="margin-top:14px;">密度</div>
                        <div class="web-toggle-row">${densityMarkup}</div>
                    </div>
                    <div class="profile-hint">当前是 ${escapeHtml(getWebThemePreset().label)} · ${escapeHtml(getWebDensityLabel())} 模式。</div>
                </section>
            `;
        }

        function renderNextActionSection() {
            return renderJourneySection('dashboard');
        }

        function renderHandoffHubSection() {
            const bridge = normalizeBridge(state.bridge || {});
            const importedFromDesktop = bridge.source === 'desktop';
            const importedAt = bridge.importedAt ? escapeHtml(formatDisplayDate(bridge.importedAt)) : '还没有接收过';
            const reportLabel = bridge.reportTitle
                ? escapeHtml(bridge.reportTitle)
                : '当前还没有桌面端交接报告';

            return `
                <section class="panel panel-body handoff-hub">
                    <div class="panel-header">
                        <div>
                            <h3 class="panel-title">桌面 / Web 统一交接入口</h3>
                            <p class="panel-subtitle">桌面端做直读和本地整理，网页版做结果浏览和继续经营。两边各自能用，交接只是额外加的一条通路。</p>
                        </div>
                        <div class="detail-actions">
                            <button class="chip-btn" data-action="open-handoff-modal" type="button">打开交接窗口</button>
                        </div>
                    </div>
                    <div class="handoff-grid">
                        <article class="handoff-card handoff-card-strong">
                            <div class="next-action-kicker">Desktop → Web</div>
                            <h4>接收桌面端交接包</h4>
                            <p>桌面端直读或导入完成后，把结果导成桥接包带到这里继续看。网页端会继续保留联系人、报告、消息建议和礼物页。</p>
                            <div class="handoff-list">
                                <div class="handoff-list-item">1. 桌面端导出桥接包。</div>
                                <div class="handoff-list-item">2. 网页端点“接收桌面交接包”。</div>
                                <div class="handoff-list-item">3. 继续按“总览 → 联系人 → 报告 → 消息 → 礼物”往下走。</div>
                            </div>
                            <div class="detail-actions">
                                <button class="solid-btn" data-action="import-data" type="button">接收桌面交接包</button>
                                <button class="ghost-btn" data-action="open-handoff-modal" type="button">看交接说明</button>
                            </div>
                            <div class="handoff-status">
                                <strong>${importedFromDesktop ? '最近一次桌面同步已接收' : '当前还没有接收桌面结果'}</strong>
                                <span>时间：${importedAt}</span>
                                <span>${importedFromDesktop ? `联系人 ${bridge.contactCount} · 摘要消息 ${bridge.recordCount} · 导入批次 ${bridge.packageCount}` : '接收后这里会显示来自桌面端的联系人数量和报告状态。'}</span>
                                <span>报告：${reportLabel}</span>
                            </div>
                        </article>
                        <article class="handoff-card">
                            <div class="next-action-kicker">Web → Desktop</div>
                            <h4>需要直读微信时，回桌面端</h4>
                            <p>网页版继续负责演示、查看结果、轻量整理和 AI 追问；真正要读本机微信数据库、导入多年历史和处理原始附件时，仍然请用桌面版。</p>
                            <div class="handoff-list">
                                <div class="handoff-list-item">当前网页端仍保留原来的网页 JSON 导入导出。</div>
                                <div class="handoff-list-item">不会因为接收桌面交接包，就改变你原来的网页版使用方式。</div>
                                <div class="handoff-list-item">对外表达时，可以讲成“桌面端重整理，网页版轻查看”。</div>
                            </div>
                            <div class="detail-actions">
                                <button class="ghost-btn" data-action="export-data" type="button">导出网页数据</button>
                                <button class="ghost-btn" data-nav="profile" type="button">看设置与说明</button>
                            </div>
                        </article>
                    </div>
                </section>
            `;
        }

        function renderHandoffModalBody() {
            const bridge = normalizeBridge(state.bridge || {});
            const importedFromDesktop = bridge.source === 'desktop';
            const importedAt = bridge.importedAt ? escapeHtml(formatDisplayDate(bridge.importedAt)) : '还没有';
            const reportLabel = bridge.reportTitle
                ? escapeHtml(bridge.reportTitle)
                : '还没有桌面端报告';
            const host = document.getElementById('handoff-modal-body');
            if (!host) return;

            host.innerHTML = `
                <div class="handoff-modal-grid">
                    <section class="handoff-modal-card">
                        <div class="next-action-kicker">Desktop → Web</div>
                        <h4>从桌面端把结果交给网页版</h4>
                        <p>接收的是桌面端导出的桥接包，不是浏览器直接读你的微信数据库。这能保证桌面直读继续稳定，网页端继续轻量。</p>
                        <div class="handoff-list">
                            <div class="handoff-list-item">桌面端完成直读后，导出一份桥接 JSON。</div>
                            <div class="handoff-list-item">网页端点击下方按钮接收。</div>
                            <div class="handoff-list-item">导入后默认回总览，继续沿着新手路径往下看。</div>
                        </div>
                        <div class="detail-actions">
                            <button class="solid-btn" data-action="import-data" type="button">接收桌面交接包</button>
                        </div>
                    </section>
                    <section class="handoff-modal-card">
                        <div class="next-action-kicker">Web → Desktop</div>
                        <h4>网页版看结果，桌面版做直读</h4>
                        <p>两边的定位已经固定下来：网页版做结果浏览、轻量整理和 AI 追问；桌面版做微信直读、本地整理和原始附件处理。</p>
                        <div class="handoff-status">
                            <strong>${importedFromDesktop ? '这份网页工作台当前来自桌面端' : '这份网页工作台当前还是本地网页数据'}</strong>
                            <span>最近同步：${importedAt}</span>
                            <span>${importedFromDesktop ? `联系人 ${bridge.contactCount} · 摘要消息 ${bridge.recordCount}` : '你可以先在这里体验，再决定要不要切桌面版。'}</span>
                            <span>报告：${reportLabel}</span>
                        </div>
                        <div class="detail-actions">
                            <button class="ghost-btn" data-action="export-data" type="button">导出网页数据</button>
                            <button class="ghost-btn" data-nav="dashboard" type="button">回到总览</button>
                        </div>
                    </section>
                </div>
                <p class="handoff-note">这条交接不会改变你原来两个端各自的主流程，只是把“桌面端重整理，网页端轻查看”收成一条更像产品能力的统一入口。</p>
            `;
        }

        function openHandoffModal() {
            renderHandoffModalBody();
            document.getElementById('handoff-modal').classList.add('open');
            document.getElementById('handoff-modal').setAttribute('aria-hidden', 'false');
        }

        function closeHandoffModal() {
            const modal = document.getElementById('handoff-modal');
            if (!modal) return;
            modal.classList.remove('open');
            modal.setAttribute('aria-hidden', 'true');
        }

        function renderDashboard() {
            const host = document.getElementById('page-dashboard');
            if (!host) return;
            const relationships = state.relationships;
            const currentUser = getCurrentUser();
            const averageIntimacy = relationships.length
                ? Math.round(relationships.reduce((sum, item) => sum + Number(item.intimacy || 0), 0) / relationships.length)
                : 0;
            const onTrackCount = relationships.filter((item) => getCadenceGap(item) === 0).length;
            const averageWeeklyFrequency = relationships.length
                ? (relationships.reduce((sum, item) => sum + Number(item.weeklyFrequency || 0), 0) / relationships.length).toFixed(1)
                : '0.0';
            const upcomingBirthdays = getUpcomingBirthdays().slice(0, 3);
            const focusTargets = getFocusTargets().slice(0, 3);
            const latestReport = state.analyses[0];
            const latestReportTitle = latestReport?.title || '还没有报告';
            const nextBirthday = upcomingBirthdays[0];
            const focusListMarkup = focusTargets.length
                ? focusTargets.map(renderFocusCard).join('')
                : '<div class="empty-state">先新增一位关系对象，我们再给出优先级建议。</div>';
            const birthdayListMarkup = upcomingBirthdays.length
                ? upcomingBirthdays.map(renderBirthdayCard).join('')
                : '<div class="empty-state">目前还没有填写生日信息。</div>';
            const latestReportMarkup = latestReport
                ? `<div class="report-card active"><div class="report-head"><div><h4>${escapeHtml(latestReport.title)}</h4><p class="analysis-summary">${escapeHtml(latestReport.summary)}</p></div><div class="badge">${latestReport.score} 分</div></div></div>`
                : '<div class="empty-state">点击“生成分析报告”后，这里会出现最新结果。</div>';

            const markup = `
                <div class="dashboard-shell">
                    <section class="panel hero-card dashboard-lead">
                        <div class="dashboard-primary">
                            <div class="dashboard-copy">
                                <div class="mode-pill">${currentUser ? `欢迎回来 · ${escapeHtml(currentUser.name)}` : '网页端先看结果 / 桌面端做深处理'}</div>
                                <h3 class="hero-title">网页端先判断重点，桌面端再做本地深整理。</h3>
                                <p class="hero-copy">这里更像一个轻工作区：先看重点对象、最近报告和下一步动作。真正需要直读微信、扫多年历史和处理原始附件时，再切到桌面版。</p>
                            </div>
                            <div class="dashboard-stat-strip">
                                <div class="dashboard-stat-item">
                                    <span class="dashboard-stat-label">已管理关系</span>
                                    <strong>${relationships.length}</strong>
                                    <small>覆盖 ${Object.keys(groupByType(relationships)).length} 类关系</small>
                                </div>
                                <div class="dashboard-stat-item">
                                    <span class="dashboard-stat-label">本周稳定</span>
                                    <strong>${onTrackCount}</strong>
                                    <small>达到建议交流频率</small>
                                </div>
                                <div class="dashboard-stat-item">
                                    <span class="dashboard-stat-label">平均亲密度</span>
                                    <strong>${averageIntimacy}</strong>
                                    <small>由频率和重要排序推断</small>
                                </div>
                                <div class="dashboard-stat-item">
                                    <span class="dashboard-stat-label">平均周交流</span>
                                    <strong>${averageWeeklyFrequency}</strong>
                                    <small>次 / 每位联系人</small>
                                </div>
                            </div>
                            <div class="hero-actions">
                                <button class="solid-btn" data-nav="relationships" type="button">先看联系人</button>
                                <button class="ghost-btn" data-nav="analysis" type="button">查看报告</button>
                                <button class="ghost-btn" data-nav="messages" type="button">继续消息</button>
                            </div>
                        </div>
                        <aside class="dashboard-aside">
                            <section class="dashboard-brief-card">
                                <span class="next-action-kicker">今天先做</span>
                                <h4>${escapeHtml(focusTargets[0]?.name ? `先判断 ${focusTargets[0].name} 这段关系` : '先看报告和联系人' )}</h4>
                                <p>${escapeHtml(focusTargets[0]?.name ? `${focusTargets[0].name} 目前是最值得先处理的对象，先看关系理由和最近建议，再决定要不要继续补资料。` : '当前还没有明确重点对象，先导入一份记录，网页端就会把优先顺序整理出来。')}</p>
                            </section>
                            <div class="dashboard-note-list">
                                <div class="dashboard-note-row">
                                    <strong>最近报告</strong>
                                    <span>${escapeHtml(latestReportTitle)}</span>
                                </div>
                                <div class="dashboard-note-row">
                                    <strong>下一个生日</strong>
                                    <span>${escapeHtml(nextBirthday ? `${nextBirthday.name} · ${nextBirthday.birthday}` : '目前还没有填写生日信息')}</span>
                                </div>
                                <div class="dashboard-note-row">
                                    <strong>当前保存位置</strong>
                                    <span>浏览器本地</span>
                                </div>
                            </div>
                        </aside>
                    </section>

                    <div class="dashboard-support-grid">
                        <div class="dashboard-column">
                            ${renderNextActionSection()}
                            ${renderDashboardRadarSection()}
                            <section class="panel panel-body dashboard-action-panel">
                                <div class="panel-header">
                                    <div>
                                        <h3 class="panel-title">今天先走这条短路径</h3>
                                        <p class="panel-subtitle">先判断重点对象，再读结论，最后才去补消息或接桌面端数据，不要一上来就把页面都点一遍。</p>
                                    </div>
                                </div>
                                <div class="dashboard-action-list">
                                    <button class="dashboard-action-row" data-nav="relationships" type="button">
                                        <strong>先看联系人</strong>
                                        <span>先看排序、原因和每段关系现在该怎么维护。</span>
                                    </button>
                                    <button class="dashboard-action-row" data-nav="analysis" type="button">
                                        <strong>再看报告</strong>
                                        <span>把结论、风险点和下一步动作集中看完。</span>
                                    </button>
                                    <button class="dashboard-action-row" data-nav="messages" type="button">
                                        <strong>继续消息</strong>
                                        <span>确认人像，再继续写回复或补一段近况。</span>
                                    </button>
                                    <button class="dashboard-action-row" data-action="import-data" type="button">
                                        <strong>接收桌面包</strong>
                                        <span>支持网页 JSON 和桌面桥接包，不读取本机微信数据库。</span>
                                    </button>
                                </div>
                            </section>
                            <section class="panel panel-body">
                                <div class="panel-header">
                                    <div>
                                        <h3 class="panel-title">今日优先队列</h3>
                                        <p class="panel-subtitle">这 3 段关系最值得先处理，每张卡都能直接跳去关系、消息或礼物页。</p>
                                    </div>
                                </div>
                                <div class="focus-list">${focusListMarkup}</div>
                            </section>
                        </div>
                        <div class="dashboard-column">
                            <section class="panel panel-body dashboard-stack-panel">
                                <div class="panel-header">
                                    <div>
                                        <h3 class="panel-title">最近结果与提醒</h3>
                                        <p class="panel-subtitle">先看最近一份结果，再看生日提醒和接下来要不要切去桌面端。</p>
                                    </div>
                                    <button class="chip-btn" data-nav="analysis" type="button">查看全部</button>
                                </div>
                                ${latestReportMarkup}
                                <div class="dashboard-divider"></div>
                                <div class="birthday-list">${birthdayListMarkup}</div>
                            </section>
                            ${renderHandoffHubSection()}
                            ${renderWebDisplaySettingsSection()}
                        </div>
                    </div>
                    ${renderWebGuideSection()}
                </div>
            `;
            if (host.innerHTML === markup) {
                return;
            }
            host.innerHTML = markup;
        }

        function renderBirthdayCard(item) {
            const dayLabel = item.days === 0 ? '今天' : `${item.days} 天后`;
            return `
                <div class="birthday-card">
                    <div class="birthday-head">
                        <div>
                            <h4>${escapeHtml(item.name)}</h4>
                            <p class="analysis-summary">${escapeHtml(`${dayLabel} · ${item.birthday}`)}</p>
                        </div>
                        <div class="badge">${dayLabel}</div>
                    </div>
                </div>
            `;
        }

        function renderProfile() {
            const host = document.getElementById('page-profile');
            if (!host) return;
            const currentUser = getCurrentUser();
            const healthBadge = serviceHealth.loading
                ? '检测中'
                : serviceHealth.checked
                    ? serviceHealth.aiAvailable
                        ? 'AI 已连接'
                        : 'AI 未连接'
                    : '待检测';
            const healthSummary = serviceHealth.loading
                ? '正在检测 API、地理位置和视觉能力，请稍候。'
                : serviceHealth.checked
                    ? serviceHealth.error
                        ? `最近一次检测失败：${serviceHealth.error}`
                        : `文本模型：${serviceHealth.textModel}；视觉模型：${serviceHealth.visionModel}`
                    : '还没有检测当前网页环境的 AI 与地理服务状态。';

            host.innerHTML = `
                <div class="profile-grid">
                    <section class="panel panel-body">
                        <div class="panel-header">
                            <div>
                                <h3 class="panel-title">我的资料</h3>
                                <p class="panel-subtitle">这些资料只保存在当前浏览器，用于辅助网页端分析和展示。</p>
                            </div>
                            <div class="badge">${escapeHtml(currentUser?.name || '本地资料')}</div>
                        </div>
                        <form id="profile-form" class="field-grid">
                            <div class="field">
                                <label for="profile-name">昵称</label>
                                <input class="input" id="profile-name" name="name" maxlength="24" value="${escapeHtml(state.profile.name)}" placeholder="例如：林知夏">
                            </div>
                            <div class="field">
                                <label for="profile-title">身份说明</label>
                                <input class="input" id="profile-title" name="title" maxlength="40" value="${escapeHtml(state.profile.title)}" placeholder="例如：自由职业者 / 关系经营实践者">
                            </div>
                            <div class="field">
                                <label for="profile-city">所在城市</label>
                                <input class="input" id="profile-city" name="city" maxlength="24" value="${escapeHtml(state.profile.city)}" placeholder="例如：杭州">
                            </div>
                            <div class="field">
                                <label for="profile-phone">手机号</label>
                                <input class="input" id="profile-phone" name="phone" maxlength="24" value="${escapeHtml(state.profile.phone)}" placeholder="可选">
                            </div>
                            <div class="field full">
                                <label for="profile-bio">补充说明</label>
                                <textarea class="textarea" id="profile-bio" name="bio" rows="5" placeholder="例如：希望用更轻松的方式，把重要关系维护成长期资产。">${escapeHtml(state.profile.bio)}</textarea>
                            </div>
                            <div class="detail-actions">
                                <button class="solid-btn" type="submit">保存资料</button>
                            </div>
                        </form>
                    </section>

                    <div class="focus-list">
                        <section class="panel panel-body settings-card">
                            <div class="panel-header">
                                <div>
                                    <h3 class="panel-title">网页使用偏好</h3>
                                    <p class="panel-subtitle">这些开关只影响当前浏览器，不会改动桌面版数据。</p>
                                </div>
                            </div>
                            <div class="toggle-row">
                                <div>
                                    <strong>每周摘要</strong>
                                    <p class="analysis-summary">保留总览里的节奏提醒和重点变化。</p>
                                </div>
                                <label class="switch">
                                    <input type="checkbox" data-setting-key="weeklyDigest" ${state.settings.weeklyDigest ? 'checked' : ''}>
                                    <span></span>
                                </label>
                            </div>
                            <div class="toggle-row">
                                <div>
                                    <strong>生日提醒</strong>
                                    <p class="analysis-summary">在总览和礼物页提前提示临近生日对象。</p>
                                </div>
                                <label class="switch">
                                    <input type="checkbox" data-setting-key="birthdayReminder" ${state.settings.birthdayReminder ? 'checked' : ''}>
                                    <span></span>
                                </label>
                            </div>
                            <div class="toggle-row">
                                <div>
                                    <strong>隐私模式</strong>
                                    <p class="analysis-summary">减少页面上的敏感提示，适合公开环境使用。</p>
                                </div>
                                <label class="switch">
                                    <input type="checkbox" data-setting-key="privacyMode" ${state.settings.privacyMode ? 'checked' : ''}>
                                    <span></span>
                                </label>
                            </div>
                            <div class="toggle-row">
                                <div>
                                    <strong>云端人像分析</strong>
                                    <p class="analysis-summary">需要时才启用，图片会先在浏览器本地压缩并去除元数据。</p>
                                </div>
                                <label class="switch">
                                    <input type="checkbox" id="cloud-portrait-opt-in" ${secretState.cloudPortraitOptIn ? 'checked' : ''}>
                                    <span></span>
                                </label>
                            </div>
                        </section>

                        <section class="panel panel-body ai-settings-card">
                            <div class="panel-header">
                                <div>
                                    <h3 class="panel-title">网页环境状态</h3>
                                    <p class="panel-subtitle">这里看当前网页端的 AI、视觉与地理服务是否可用。</p>
                                </div>
                                <div class="badge ${serviceHealth.aiAvailable ? '' : 'warn'}">${healthBadge}</div>
                            </div>
                            <div class="focus-list">
                                <div class="focus-card">
                                    <h4>当前模型</h4>
                                    <p>${escapeHtml(healthSummary)}</p>
                                </div>
                                <div class="focus-card">
                                    <h4>能力开关</h4>
                                    <p>${escapeHtml(`AI：${serviceHealth.aiAvailable ? '可用' : '不可用'} / 视觉：${serviceHealth.portraitAvailable ? '可用' : '不可用'} / 地理：${serviceHealth.geoAvailable ? '可用' : '不可用'}`)}</p>
                                </div>
                            </div>
                            <div class="detail-actions">
                                <button class="ghost-btn" data-action="refresh-api-health" type="button">${serviceHealth.loading ? '正在检测...' : '刷新连接状态'}</button>
                                <button class="ghost-btn" data-action="reset-demo" type="button">恢复演示数据</button>
                            </div>
                        </section>
                    </div>
                </div>
            `;
        }

        function renderRelationshipCard(item, selected) {
            const active = selected && selected.id === item.id;
            const distance = getCachedDistanceForRelationship(item);
            return `
                <button class="relationship-card ${active ? 'active' : ''}" data-action="select-relationship" data-id="${item.id}" type="button">
                    <div class="relationship-head">
                        <div class="name-block">
                            <strong>${escapeHtml(item.name)}</strong>
                            <div class="subline">
                                <span>${escapeHtml(RELATION_LABELS[item.type])}</span>
                                <span>周交流 ${item.weeklyFrequency} 次</span>
                                <span>月深聊 ${item.monthlyDepth} 次</span>
                                <span>${escapeHtml(getImportanceDisplay(item))}</span>
                                ${distance !== null ? `<span>${formatDistanceKm(distance)}</span>` : ''}
                            </div>
                        </div>
                        <div class="badge">${item.intimacy}</div>
                    </div>
                    <div class="progress"><span style="width:${item.intimacy}%;"></span></div>
                    <p class="detail-copy">${escapeHtml(item.note || '系统会根据你们的互动频率自动判断关系状态。')}</p>
                    <div class="detail-tags">${item.tags.length ? item.tags.map((tag) => `<span class="tag">${escapeHtml(tag)}</span>`).join('') : '<span class="profile-hint">暂无标签</span>'}</div>
                </button>
            `;
        }

        function renderMessageThreadCard(thread, selected) {
            const item = thread.relationship;
            const active = selected && selected.id === item.id;
            const portraitReady = item.portraitProfile?.summary ? `<span class="portrait-chip">已生成人像档案</span>` : '';
            return `
                <button class="thread-card ${active ? 'active' : ''}" data-action="select-message-thread" data-id="${item.id}" type="button">
                    <div class="thread-head">
                        <div>
                            <strong>${escapeHtml(item.name)}</strong>
                            <div class="analysis-summary">${escapeHtml(RELATION_LABELS[item.type])} · ${escapeHtml(thread.channel)}</div>
                        </div>
                        <div class="badge ${thread.unread ? 'warn' : ''}">${thread.unread ? `${thread.unread} 条待跟进` : '稳定'}</div>
                    </div>
                    <div class="thread-meta">
                        <span class="analysis-summary">${escapeHtml(getImportanceDisplay(item))}</span>
                        <span class="analysis-summary">${escapeHtml(item.lastContact || '未记录时间')}</span>
                    </div>
                    <p class="thread-snippet">${escapeHtml(thread.summary)}</p>
                    <div class="portrait-chip-row">${portraitReady || '<span class="portrait-chip">可上传头像 / 聊天截图做人像分类</span>'}</div>
                </button>
            `;
        }

        function renderMessageBubble(entry) {
            return `
                <div class="message-bubble ${entry.role}">
                    <div>${escapeHtml(entry.text)}</div>
                    <span class="message-meta">${escapeHtml(entry.meta)}</span>
                </div>
            `;
        }

        function addManualMessage() {
            const relationship = getSelectedMessageRelationship();
            if (!relationship) {
                showToast('请先选择一个联系人会话');
                return;
            }
            const draft = getMessageDraft(relationship.id).trim();
            if (!draft) {
                showToast('先输入你想记录或发送的内容');
                return;
            }
            const message = normalizeManualMessage({
                id: `manual-${Date.now()}`,
                relationshipId: relationship.id,
                role: 'me',
                text: draft,
                meta: `我 · 手动输入 · ${new Date().toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit' })}`,
                createdAt: new Date().toISOString(),
            });
            if (!message) {
                showToast('这段内容暂时无法保存');
                return;
            }
            state.manualMessages = [...(state.manualMessages || []), message].slice(-120);
            const relationshipIndex = state.relationships.findIndex((item) => item.id === relationship.id);
            if (relationshipIndex !== -1) {
                state.relationships[relationshipIndex] = normalizeRelationship({
                    ...state.relationships[relationshipIndex],
                    lastContact: formatDate(new Date()),
                });
            }
            clearMessageDraft(relationship.id);
            renderMessages();
            persistState();
            showToast(`已把这段内容加入 ${relationship.name} 的本地会话`);
        }

        function moveDraftToAiTask() {
            const relationship = getSelectedMessageRelationship();
            if (!relationship) {
                showToast('请先选择一个联系人会话');
                return;
            }
            const draft = getMessageDraft(relationship.id).trim();
            if (!draft) {
                showToast('先输入你想让 AI 处理的内容');
                return;
            }
            state.ui.assistantTargetId = relationship.id;
            state.ui.assistantScenario = draft;
            persistState();
            openAiTaskModal(relationship.id);
            showToast(`已把输入内容带到 ${relationship.name} 的 AI 任务框`);
        }

        function renderRelationshipDetail(item) {
            const birthdayDays = item.birthday ? daysUntilBirthday(item.birthday) : null;
            const distance = getCachedDistanceForRelationship(item);
            const needs = inferRelationshipNeeds(item);
            const budget = getGiftBudgetRecommendation(item, state.ui.giftOccasion);
            const portraitProfile = item.portraitProfile;
            return `
                <section class="detail-card detail-grid">
                    <div class="detail-head"><div><h3 class="panel-title">${escapeHtml(item.name)}</h3><p class="panel-subtitle">${escapeHtml(RELATION_LABELS[item.type])} · ${escapeHtml(item.city || '未填写城市')}</p></div><div class="badge">${item.intimacy} / 100</div></div>
                    <div class="detail-stats">
                        <div class="detail-stat">每周交流<strong>${item.weeklyFrequency} 次</strong></div>
                        <div class="detail-stat">每月深聊<strong>${item.monthlyDepth} 次</strong></div>
                        <div class="detail-stat">重要层级<strong>${escapeHtml(getImportanceDisplay(item))}</strong></div>
                        <div class="detail-stat">关系强度<strong>${intimacyLevel(item.intimacy)}</strong></div>
                    </div>
                    <div class="detail-tags">${item.tags.length ? item.tags.map((tag) => `<span class="tag">${escapeHtml(tag)}</span>`).join('') : '<span class="profile-hint">可以给这段关系补几个标签，后续检索更方便。</span>'}</div>
                    <div class="signal-pill-row">
                        <div class="signal-pill">建议节奏 · 每周 ${getSuggestedWeeklyFrequency(item)} 次 / 每月 ${getSuggestedMonthlyDepth(item)} 次</div>
                        <div class="signal-pill">${distance !== null ? `距离约 ${formatDistanceKm(distance)}` : '打开地图距离视图后自动测算公里数'}</div>
                    </div>
                    <div class="detail-copy">${escapeHtml(item.note || '当前还没有补充备注，建议把对方最近在忙什么记下来。')}</div>
                    <div class="gift-advisor-card"><h4>关系判断</h4><p>${escapeHtml(needs.personalitySummary)}</p></div>
                    <div class="gift-advisor-card"><h4>人像档案</h4><p>${escapeHtml(portraitProfile?.summary || '还没有记录对方的人像印象。你可以去消息页上传头像或聊天截图，退出时确认后会自动写入。')}</p>${portraitProfile?.styleTags?.length ? `<div class="portrait-chip-row" style="margin-top:12px;">${portraitProfile.styleTags.map((tag) => `<span class="portrait-chip">${escapeHtml(tag)}</span>`).join('')}</div>` : ''}${portraitProfile?.giftHints?.length ? `<div class="gift-reason-list" style="margin-top:12px;">${portraitProfile.giftHints.map((tip) => `<div class="gift-reason-item">${escapeHtml(`送礼提示：${tip}`)}</div>`).join('')}</div>` : ''}</div>
                    <div class="gift-advisor-card"><h4>送礼区间</h4><p>${escapeHtml(budget.reason)}</p></div>
                    <div class="detail-stat">生日提醒<strong>${birthdayDays === null ? '未填' : birthdayDays === 0 ? '今天' : `${birthdayDays} 天后`}</strong></div>
                    <div class="detail-actions">
                        <button class="ghost-btn" data-action="open-message-thread" data-id="${item.id}" type="button">去消息页识别</button>
                        <button class="ghost-btn" data-action="generate-analysis" data-target-id="${item.id}" type="button">生成专属分析</button>
                        <button class="ghost-btn" data-action="open-ai-assistant" data-id="${item.id}" type="button">AI 温和回应</button>
                        <button class="ghost-btn" data-action="jump-to-gifts" data-id="${item.id}" type="button">查看礼物推荐</button>
                        <button class="ghost-btn" data-action="edit-relationship" data-id="${item.id}" type="button">编辑</button>
                        <button class="tiny-btn" data-action="delete-relationship" data-id="${item.id}" type="button">删除</button>
                    </div>
                </section>
            `;
        }

        function renderAnalysisReportCard(report, selected) {
            const active = selected && selected.id === report.id;
            return `
                <button class="report-card ${active ? 'active' : ''}" data-action="select-analysis" data-id="${report.id}" type="button">
                    <div class="report-head">
                        <div>
                            <h4>${escapeHtml(report.title)}</h4>
                            <p class="analysis-summary">${escapeHtml(report.summary)}</p>
                        </div>
                        <div class="badge">${report.score} 分</div>
                    </div>
                    <div class="analysis-summary">${escapeHtml(report.createdAt || '')}</div>
                </button>
            `;
        }

        function renderAssistantResult(result, copyAction = 'copy-ai-reply') {
            if (!result) return '<div class="empty-state">当前还没有可展示的 AI 结果。</div>';
            const sourceLabel = result.source === 'model' ? '云端 AI' : '本地兜底';
            const needsMarkup = Array.isArray(result.needs) && result.needs.length
                ? `<div class="detail-tags">${result.needs.map((item) => `<span class="tag">${escapeHtml(item)}</span>`).join('')}</div>`
                : '';
            return `
                <section class="assistant-result">
                    <div class="report-head">
                        <div>
                            <h4>${escapeHtml(result.summary || '当前建议')}</h4>
                            <p class="analysis-summary">${escapeHtml(result.createdAt || '')}</p>
                        </div>
                        <div class="badge ${result.source === 'model' ? '' : 'warn'}">${sourceLabel}</div>
                    </div>
                    <div class="assistant-output">
                        <div class="assistant-text">${escapeHtml(result.reply || '')}</div>
                        ${result.giftAdvice ? `<div class="assistant-text">${escapeHtml(result.giftAdvice)}</div>` : ''}
                    </div>
                    <div class="assistant-metrics">
                        <div class="assistant-metric">
                            <span class="metric-label">当前预算提示</span>
                            <strong>${escapeHtml(result.budgetText || '待生成')}</strong>
                        </div>
                        <div class="assistant-metric">
                            <span class="metric-label">当前用途</span>
                            <strong>${escapeHtml(result.intent || '综合建议')}</strong>
                        </div>
                    </div>
                    ${needsMarkup}
                    <div class="detail-actions">
                        <button class="ghost-btn" data-action="${copyAction}" type="button">复制当前回复</button>
                    </div>
                </section>
            `;
        }

        function renderRelationships() {
            const host = document.getElementById('page-relationships');
            if (!host) return;
            const relationships = getFilteredRelationships();
            const selected = relationships.find((item) => item.id === state.ui.selectedRelationshipId)
                || findRelationshipById(state.ui.selectedRelationshipId)
                || relationships[0]
                || state.relationships[0]
                || null;
            const journeyMarkup = renderJourneySection('relationships');
            const pageGuideMarkup = renderPageGuideSection('relationships');
            const journeyToggleMarkup = renderJourneyReopenButton();
            const guideToggleMarkup = isPageGuideDismissed('relationships')
                ? '<button class="chip-btn" data-action="reopen-page-guide" data-guide="relationships" type="button">重新看教程</button>'
                : '';

            if (selected && state.ui.selectedRelationshipId !== selected.id) {
                state.ui.selectedRelationshipId = selected.id;
            }

            const visibleState = getVisibleRelationships(relationships, selected);
            const listMarkup = visibleState.visible.length
                ? visibleState.visible.map((item) => renderRelationshipCard(item, selected)).join('')
                : '<div class="empty-state">当前筛选条件下还没有联系人。先重置筛选，或新增一位关系对象。</div>';
            const loadMoreMarkup = visibleState.remainingCount > 0
                ? `
                    <div class="detail-actions" style="justify-content: space-between; margin-top: 14px; gap: 12px; flex-wrap: wrap;">
                        <div class="analysis-summary">当前先显示 ${visibleState.visible.length} / ${relationships.length} 位联系人，避免这一页一次性渲染过重。</div>
                        <button class="ghost-btn" data-action="show-more-relationships" type="button">继续加载 ${Math.min(visibleState.remainingCount, RELATIONSHIP_RENDER_BATCH)} 位</button>
                    </div>
                `
                : '';

            const viewButtons = [
                { key: 'list', label: '列表' },
                { key: 'graph', label: '距离图' },
            ];
            const filterButtons = [
                { key: 'all', label: '全部' },
                ...Object.entries(RELATION_LABELS).map(([key, label]) => ({ key, label })),
            ];
            const filterMarkup = filterButtons.map((entry) => `
                <button class="chip-btn ${state.ui.relationFilter === entry.key ? 'active' : ''}" data-action="set-relation-filter" data-filter="${entry.key}" type="button">${escapeHtml(entry.label)}</button>
            `).join('');

            const directionMarkup = `
                <div class="distance-pill-row">
                    <div class="distance-pill">先选左侧联系人</div>
                    <div class="distance-pill">再看右侧原因和建议</div>
                    <div class="distance-pill">想看距离时切换到“距离图”</div>
                </div>
            `;

            const graphMarkup = `
                <div class="relationship-layout">
                    <div class="map-stack">
                        <section class="panel panel-body map-panel">
                            <div class="panel-header">
                                <div>
                                    <h3 class="panel-title">关系距离图</h3>
                                    <p class="panel-subtitle">当你填写了自己的城市和联系人城市后，这里会画出大致距离。它不是关系分，只是帮助你判断见面和维护成本。</p>
                                </div>
                                <div class="badge">距离辅助</div>
                            </div>
                            <div class="map-meta" id="relationship-map-meta">如果你还没填城市，请先到“设置”页补上你的所在城市。</div>
                            <div class="distance-pill-row" id="relationship-distance-pills"></div>
                            <div class="relationship-map-shell">
                                <div class="relationship-map-canvas" id="relationship-map"></div>
                            </div>
                        </section>
                        <section class="panel panel-body">
                            <div class="panel-header">
                                <div>
                                    <h3 class="panel-title">当前联系人</h3>
                                    <p class="panel-subtitle">关系判断仍以互动频率和重要层级为主，距离只作为现实成本参考。</p>
                                </div>
                            </div>
                            ${selected ? renderRelationshipDetail(selected) : '<div class="empty-state">先从左侧选择一位联系人。</div>'}
                        </section>
                    </div>
                    <div class="relationship-list">${listMarkup}${loadMoreMarkup}</div>
                </div>
            `;

            host.innerHTML = `
                ${journeyMarkup}
                <section class="panel panel-body">
                    <div class="panel-header">
                        <div>
                            <h3 class="panel-title">联系人洞察</h3>
                            <p class="panel-subtitle">这里先回答三件事：谁更重要、为什么这样判断、我下一步该联系谁。</p>
                        </div>
                        <div class="detail-actions">
                            ${journeyToggleMarkup}
                            ${guideToggleMarkup}
                            ${viewButtons.map((entry) => `<button class="chip-btn ${state.ui.relationView === entry.key ? 'active' : ''}" data-action="set-relation-view" data-view="${entry.key}" type="button">${entry.label}</button>`).join('')}
                            <button class="ghost-btn" data-action="open-add-modal" type="button">新增联系人</button>
                        </div>
                    </div>
                    <div class="toolbar">
                        <input class="input" id="relationship-search" value="${escapeAttribute(state.ui.relationSearch || '')}" placeholder="搜姓名、标签、备注或城市">
                    </div>
                    <div class="toolbar">${filterMarkup}</div>
                    ${pageGuideMarkup}
                    ${directionMarkup}
                    ${state.ui.relationView === 'graph'
                        ? graphMarkup
                        : `<div class="relationship-layout"><div class="relationship-list">${listMarkup}${loadMoreMarkup}</div><div>${selected ? renderRelationshipDetail(selected) : '<div class="empty-state">先从左侧选择一位联系人。</div>'}</div></div>`}
                </section>
            `;

            if (state.ui.relationView === 'graph') {
                scheduleRelationshipMap(relationships, selected);
            } else {
                scheduleRelationshipMap([], null);
            }
        }

        function renderAnalysis() {
            const host = document.getElementById('page-analysis');
            if (!host) return;
            const selectedReport = state.analyses.find((item) => item.id === state.ui.selectedAnalysisId)
                || state.analyses[0]
                || null;
            const target = findRelationshipById(state.ui.assistantTargetId) || state.relationships[0] || null;
            const personality = buildPersonalityProfile();
            const latestAssistant = target ? getLatestAssistantRecordForTarget(target.id) : getLatestAssistantRecord();
            const journeyMarkup = renderJourneySection('analysis');
            const pageGuideMarkup = renderPageGuideSection('analysis');
            const journeyToggleMarkup = renderJourneyReopenButton();
            const guideToggleMarkup = isPageGuideDismissed('analysis')
                ? '<button class="chip-btn" data-action="reopen-page-guide" data-guide="analysis" type="button">重新看教程</button>'
                : '';

            if (selectedReport && state.ui.selectedAnalysisId !== selectedReport.id) {
                state.ui.selectedAnalysisId = selectedReport.id;
            }

            const visibleReports = getVisibleAnalysisReports(state.analyses, selectedReport);
            const reportListMarkup = visibleReports.visible.length
                ? visibleReports.visible.map((item) => renderAnalysisReportCard(item, selectedReport)).join('')
                : '<div class="empty-state">先生成一份报告，这里才会出现分析结果。</div>';
            const reportLoadMoreMarkup = visibleReports.remainingCount > 0
                ? `
                    <div class="detail-actions" style="justify-content: space-between; margin-top: 14px; gap: 12px; flex-wrap: wrap;">
                        <div class="analysis-summary">当前先显示 ${visibleReports.visible.length} / ${state.analyses.length} 份报告，避免这一栏一次性渲染过重。</div>
                        <button class="ghost-btn" data-action="show-more-analyses" type="button">继续加载 ${Math.min(visibleReports.remainingCount, ANALYSIS_RENDER_BATCH)} 份</button>
                    </div>
                `
                : '';

            const selectedReportMarkup = selectedReport
                ? `
                    <section class="panel panel-body">
                        <div class="panel-header">
                            <div>
                                <h3 class="panel-title">${escapeHtml(selectedReport.title)}</h3>
                                <p class="panel-subtitle">${escapeHtml(selectedReport.createdAt || '刚刚生成')}</p>
                            </div>
                            <div class="analysis-score">${selectedReport.score}</div>
                        </div>
                        <div class="analysis-overview">
                            <div class="insight-item">
                                <strong>结论</strong>
                                <p class="analysis-summary">${escapeHtml(selectedReport.summary)}</p>
                            </div>
                            <div class="analysis-list">
                                ${(selectedReport.insights || []).map((item) => `<div class="insight-item">${escapeHtml(item)}</div>`).join('')}
                            </div>
                            <div class="analysis-suggestions">
                                ${(selectedReport.suggestions || []).map((item) => `<div class="gift-reason-item">${escapeHtml(item)}</div>`).join('')}
                            </div>
                        </div>
                    </section>
                `
                : '<div class="empty-state">当前还没有选中的报告。</div>';

            const assistantMarkup = target
                ? `
                    <section class="panel panel-body assistant-card">
                        <div class="panel-header">
                            <div>
                                <h3 class="panel-title">AI 继续帮你往下走</h3>
                                <p class="panel-subtitle">先选对象和目的，再让 AI 给你一条自然一点的回复或跟进建议。</p>
                            </div>
                            <div class="badge ${serviceHealth.aiAvailable ? '' : 'warn'}">${serviceHealth.aiAvailable ? 'AI 已连接' : '本地兜底'}</div>
                        </div>
                        <div class="field-grid">
                            <div class="field">
                                <label for="assistant-target">对象</label>
                                <select class="select" id="assistant-target">
                                    ${state.relationships.map((item) => `<option value="${item.id}" ${target.id === item.id ? 'selected' : ''}>${escapeHtml(item.name)} · ${escapeHtml(RELATION_LABELS[item.type])}</option>`).join('')}
                                </select>
                            </div>
                            <div class="field">
                                <label for="assistant-intent">沟通目的</label>
                                <select class="select" id="assistant-intent">
                                    ${ASSISTANT_INTENTS.map((intent) => `<option value="${intent}" ${state.ui.assistantIntent === intent ? 'selected' : ''}>${intent}</option>`).join('')}
                                </select>
                            </div>
                            <div class="field full">
                                <label for="assistant-scenario">你想让 AI 处理什么</label>
                                <textarea class="textarea" id="assistant-scenario" rows="5" placeholder="例如：帮我给她回一条更自然的消息，不要太模板。">${escapeHtml(state.ui.assistantScenario || '')}</textarea>
                            </div>
                        </div>
                        <div class="assistant-toolbar">
                            <button class="solid-btn" data-action="generate-ai-assistant" type="button">${aiPending ? '正在生成...' : '生成回应'}</button>
                            <button class="ghost-btn" data-action="open-ai-task-modal" type="button">打开完整任务框</button>
                        </div>
                        ${latestAssistant ? renderAssistantResult(latestAssistant, 'copy-ai-reply') : '<div class="empty-state">先输入任务内容，再点“生成回应”。</div>'}
                    </section>
                `
                : '<div class="empty-state">先新增至少一位联系人，AI 才知道要围绕谁给建议。</div>';

            const personalityMarkup = personality.traits.map((trait) => `
                <div class="trait-bar">
                    <div class="trait-head">
                        <span>${escapeHtml(trait.name)}</span>
                        <span>${trait.score}</span>
                    </div>
                    <div class="progress"><span style="width:${trait.score}%;background:${escapeAttribute(trait.color)};"></span></div>
                    <div class="analysis-summary">${escapeHtml(trait.description)}</div>
                </div>
            `).join('');

            host.innerHTML = `
                ${journeyMarkup}
                ${pageGuideMarkup}
                <div class="analysis-layout">
                    <div class="analysis-list">
                        <section class="panel panel-body">
                            <div class="panel-header">
                                <div>
                                    <h3 class="panel-title">报告列表</h3>
                                    <p class="panel-subtitle">先看报告，再决定今天先经营哪段关系。</p>
                                </div>
                                <div class="detail-actions">
                                    ${journeyToggleMarkup}
                                    ${guideToggleMarkup}
                                    <select class="select" id="analysis-target" style="min-width: 190px;">
                                        <option value="all">全部关系</option>
                                        ${state.relationships.map((item) => `<option value="${item.id}">${escapeHtml(item.name)} · ${escapeHtml(RELATION_LABELS[item.type])}</option>`).join('')}
                                    </select>
                                    <button class="solid-btn" data-action="generate-analysis-from-select" type="button">生成一份报告</button>
                                </div>
                            </div>
                            <div class="report-list">${reportListMarkup}${reportLoadMoreMarkup}</div>
                        </section>
                        ${selectedReportMarkup}
                    </div>
                    <div class="analysis-list">
                        ${assistantMarkup}
                        <section class="panel panel-body">
                            <div class="panel-header">
                                <div>
                                    <h3 class="panel-title">你的关系结构画像</h3>
                                    <p class="panel-subtitle">这是网页端根据当前关系结构给出的粗画像，只用于帮助你理解维护节奏。</p>
                                </div>
                            </div>
                            <div class="personality-list">${personalityMarkup}</div>
                        </section>
                    </div>
                </div>
            `;
        }

        function renderGiftCard(gift, selectedRelationship) {
            const favorite = state.favorites.includes(gift.id);
            const reasons = [gift.reason];
            if (selectedRelationship) {
                reasons.push(`当前对象：${selectedRelationship.name} · ${RELATION_LABELS[selectedRelationship.type]} · 建议预算 ${getGiftBudgetRecommendation(selectedRelationship, state.ui.giftOccasion).label}`);
            }
            return `
                <article class="gift-card">
                    <div class="gift-head">
                        <div>
                            <h4>${escapeHtml(gift.name)}</h4>
                            <p class="analysis-summary">${escapeHtml(gift.tone)}</p>
                        </div>
                        <div class="badge">${gift.matchScore} 分</div>
                    </div>
                    <div class="gift-meta">
                        <span class="tag">${escapeHtml(gift.occasion.join(' / '))}</span>
                        <span class="tag">${escapeHtml(gift.relationTypes.map((item) => RELATION_LABELS[item] || item).join(' / '))}</span>
                    </div>
                    <div class="price-tag">¥${gift.price}</div>
                    <div class="gift-match">当前更适合 ${escapeHtml(gift.personaTags.map((item) => TRAIT_LABELS[item] || item).join(' / '))}</div>
                    <div class="gift-reason-list">${reasons.map((item) => `<div class="gift-reason-item">${escapeHtml(item)}</div>`).join('')}</div>
                    <div class="detail-actions">
                        <button class="ghost-btn" data-action="toggle-favorite-gift" data-id="${gift.id}" type="button">${favorite ? '取消收藏' : '加入收藏'}</button>
                        <button class="ghost-btn" data-action="gift-to-analysis" data-id="${gift.id}" type="button">带到报告</button>
                    </div>
                </article>
            `;
        }

        function renderGifts() {
            const host = document.getElementById('page-gifts');
            if (!host) return;
            const selectedRelationship = getSelectedGiftRelationship();
            const visibleGifts = getFilteredGifts();
            const favoriteGifts = GIFT_CATALOG.filter((item) => state.favorites.includes(item.id));
            const budget = selectedRelationship ? getGiftBudgetRecommendation(selectedRelationship, state.ui.giftOccasion) : null;
            const needs = selectedRelationship ? inferRelationshipNeeds(selectedRelationship) : null;
            const occasionOptions = ['生日', '纪念日', '节日', '拜访'];
            const journeyMarkup = renderJourneySection('gifts');
            const pageGuideMarkup = renderPageGuideSection('gifts');
            const journeyToggleMarkup = renderJourneyReopenButton();
            const guideToggleMarkup = isPageGuideDismissed('gifts')
                ? '<button class="chip-btn" data-action="reopen-page-guide" data-guide="gifts" type="button">重新看教程</button>'
                : '';
            const giftGridMarkup = visibleGifts.length
                ? visibleGifts.map((item) => renderGiftCard(item, selectedRelationship)).join('')
                : '<div class="empty-state">当前关系、场景和预算下还没有合适礼物。可以放宽预算或切换场景。</div>';

            host.innerHTML = `
                ${journeyMarkup}
                <section class="panel panel-body gift-layout">
                    <div class="panel-header">
                        <div>
                            <h3 class="panel-title">礼物建议</h3>
                            <p class="panel-subtitle">礼物不是越贵越好，而是更适合这段关系当前的节奏、场景和表达方式。</p>
                        </div>
                        <div class="detail-actions">
                            ${journeyToggleMarkup}
                            ${guideToggleMarkup}
                        </div>
                    </div>

                    <div class="toolbar">
                        <select class="select" id="gift-target" style="min-width: 220px;">
                            ${state.relationships.map((item) => `<option value="${item.id}" ${selectedRelationship?.id === item.id ? 'selected' : ''}>${escapeHtml(item.name)} · ${escapeHtml(RELATION_LABELS[item.type])}</option>`).join('')}
                        </select>
                        ${Object.entries(RELATION_LABELS).map(([key, label]) => `<button class="chip-btn ${state.ui.giftRelation === key ? 'active' : ''}" data-action="set-gift-relation" data-relation="${key}" type="button">${escapeHtml(label)}</button>`).join('')}
                    </div>

                    <div class="toolbar">
                        ${occasionOptions.map((occasion) => `<button class="chip-btn ${state.ui.giftOccasion === occasion ? 'active' : ''}" data-action="set-gift-occasion" data-occasion="${occasion}" type="button">${occasion}</button>`).join('')}
                    </div>

                    ${pageGuideMarkup}
                    <div class="gift-advisor-grid">
                        <section class="gift-advisor-card">
                            <h4>${escapeHtml(selectedRelationship?.name || '当前对象')} 的建议预算</h4>
                            <p>${escapeHtml(budget?.reason || '先选择一个联系人，系统才知道预算该落在哪个区间。')}</p>
                            <div class="range-row" style="margin-top:14px;">
                                <div class="range-head">
                                    <span>当前预算上限</span>
                                    <span>¥${state.ui.giftBudget}</span>
                                </div>
                                <input id="gift-budget" type="range" min="80" max="2200" step="20" value="${state.ui.giftBudget}">
                            </div>
                            <div class="detail-actions" style="margin-top:14px;">
                                <button class="ghost-btn" data-action="apply-gift-budget" type="button">采用建议预算</button>
                            </div>
                        </section>

                        <section class="gift-advisor-card">
                            <h4>送礼方向</h4>
                            <p>${escapeHtml(needs?.personalitySummary || '先选择联系人后，这里会告诉你这段关系更适合什么风格的礼物。')}</p>
                            ${needs ? `<div class="detail-tags" style="margin-top:12px;">${needs.dominant.map((item) => `<span class="tag">${escapeHtml(item)}</span>`).join('')}</div>` : ''}
                            ${favoriteGifts.length ? `<div class="favorite-strip">${favoriteGifts.map((item) => `<span class="favorite-pill">${escapeHtml(item.name)}</span>`).join('')}</div>` : '<div class="analysis-summary" style="margin-top:12px;">你收藏过的礼物会显示在这里，方便回头再看。</div>'}
                        </section>
                    </div>

                    <div class="gift-grid">${giftGridMarkup}</div>
                    ${renderJourneyCompletionSection('gifts')}
                </section>
            `;
        }

        function renderMessages() {
            const host = document.getElementById('page-messages');
            if (!host) return;
            const threads = getMessageThreads();
            const selected = getSelectedMessageRelationship();
            const currentPortraitCandidate = portraitReviewState.candidate && portraitReviewState.candidate.relationshipId === selected?.id
                ? portraitReviewState.candidate
                : null;
            const portraitProfile = selected?.portraitProfile || null;
            const stream = selected ? buildMessageStream(selected) : [];
            const draft = selected ? getMessageDraft(selected.id) : '';
            const hasDraft = Boolean(draft.trim());
            const journeyMarkup = renderJourneySection('messages');
            const pageGuideMarkup = renderPageGuideSection('messages');
            const journeyToggleMarkup = renderJourneyReopenButton();
            const guideToggleMarkup = isPageGuideDismissed('messages')
                ? '<button class="chip-btn" data-action="reopen-page-guide" data-guide="messages" type="button">重新看教程</button>'
                : '';
            const visibleThreads = getVisibleMessageThreads(threads, selected);
            const threadListMarkup = visibleThreads.visible.length
                ? visibleThreads.visible.map((thread) => renderMessageThreadCard(thread, selected)).join('')
                : '<div class="empty-state">先新增联系人，消息工作台才会生成会话。</div>';
            const threadLoadMoreMarkup = visibleThreads.remainingCount > 0
                ? `
                    <div class="detail-actions" style="justify-content: space-between; margin-top: 14px; gap: 12px; flex-wrap: wrap;">
                        <div class="analysis-summary">当前先显示 ${visibleThreads.visible.length} / ${threads.length} 个线程，避免消息页一次性渲染过重。</div>
                        <button class="ghost-btn" data-action="show-more-message-threads" type="button">继续加载 ${Math.min(visibleThreads.remainingCount, MESSAGE_THREAD_RENDER_BATCH)} 个</button>
                    </div>
                `
                : '';
            host.innerHTML = `
                ${journeyMarkup}
                <section class="panel panel-body">
                    <div class="panel-header">
                        <div>
                            <h3 class="panel-title">消息工作台</h3>
                            <p class="panel-subtitle">这里会按联系人生成消息线程。只要检测到待确认的人像，离开本页时就会弹出“这是否是对方的样貌”；云端人像分析默认关闭，不会自动上传。</p>
                        </div>
                        <div class="assistant-pill-row">
                            ${journeyToggleMarkup}
                            ${guideToggleMarkup}
                            <div class="distance-pill">当前线程 · ${escapeHtml(selected?.name || '未选择')}</div>
                            <div class="distance-pill">${portraitReviewState.candidate ? '有待确认人像' : '暂无人像待确认'}</div>
                        </div>
                    </div>
                    ${pageGuideMarkup}
                    <div class="messages-layout">
                        <div class="thread-list">
                            ${threadListMarkup}${threadLoadMoreMarkup}
                        </div>
                        <div class="message-shell">
                            ${selected ? `
                                <section class="conversation-card">
                                    <div class="thread-head">
                                        <div>
                                            <h4 class="panel-title" style="font-size:18px;">${escapeHtml(selected.name)}</h4>
                                            <p class="panel-subtitle">${escapeHtml(RELATION_LABELS[selected.type])} · ${escapeHtml(getMessageChannel(selected))} · ${escapeHtml(getImportanceDisplay(selected))}</p>
                                        </div>
                                        <div class="badge">${selected.intimacy}</div>
                                    </div>
                                    <div class="conversation-stream">${stream.map(renderMessageBubble).join('')}</div>
                                    <div class="message-composer">
                                        <div class="composer-bar">
                                            <button class="composer-tool-btn" data-action="trigger-portrait-upload" type="button" title="上传图片">+</button>
                                            <div class="composer-input-shell">
                                                <textarea class="composer-textarea" id="message-composer" rows="1" placeholder="发消息、记录想法，或贴一段聊天内容">${escapeHtml(draft)}</textarea>
                                            </div>
                                            <button class="composer-send-btn ${hasDraft ? '' : 'disabled'}" data-action="save-manual-message" type="button">发送</button>
                                        </div>
                                        <div class="composer-actions">
                                            <button class="chip-btn" data-action="draft-to-ai-task" type="button">AI 润色</button>
                                            <button class="chip-btn" data-action="trigger-portrait-upload" type="button">上传人像</button>
                                            <span class="composer-hint">Enter 发送，Shift+Enter 换行</span>
                                        </div>
                                    </div>
                                </section>
                                <section class="portrait-workbench">
                                    <div class="portrait-head">
                                        <div>
                                            <h4 class="panel-title" style="font-size:16px;">人像识别工作区</h4>
                                            <p class="panel-subtitle">上传头像、朋友圈截图或聊天截图里的单人人像。系统会在你离开消息页时再请你确认是不是对方本人。</p>
                                        </div>
                                        <div class="badge ${portraitProfile ? '' : 'warn'}">${portraitProfile ? '已有档案' : '待补充'}</div>
                                    </div>
                                    <div class="portrait-upload">
                                        <label for="portrait-upload-input">导入待确认人像</label>
                                        <input id="portrait-upload-input" type="file" accept="image/*">
                                        <div class="profile-hint">当前初版只保留最近一次待确认的人像。若后续启用云端分析，图片会先在浏览器本地压缩并去除元数据。</div>
                                    </div>
                                    ${currentPortraitCandidate ? `
                                        <div class="portrait-preview-grid">
                                            <img class="portrait-preview" src="${escapeAttribute(currentPortraitCandidate.dataUrl)}" alt="${escapeAttribute(selected.name)} 的待确认人像">
                                            <div>
                                                <div class="portrait-status">已检测到一张待确认的人像。你现在切到别的页面时，会先弹窗问你“这是否是对方的样貌”。</div>
                                                <div class="portrait-copy" style="margin-top:12px;">文件：${escapeHtml(currentPortraitCandidate.fileName)} · 检测时间：${escapeHtml(currentPortraitCandidate.capturedAt)}</div>
                                            </div>
                                        </div>
                                    ` : ''}
                                    ${portraitProfile ? `
                                        <div class="portrait-preview-grid">
                                            <div class="portrait-status">AI 分类</div>
                                            <div>
                                                <div class="portrait-copy">${escapeHtml(portraitProfile.summary)}</div>
                                                <div class="portrait-chip-row" style="margin-top:12px;">${(portraitProfile.styleTags || []).map((tag) => `<span class="portrait-chip">${escapeHtml(tag)}</span>`).join('')}</div>
                                                <div class="portrait-tip-list" style="margin-top:14px;">
                                                    ${(portraitProfile.communicationHints || []).map((tip) => `<div class="portrait-tip">${escapeHtml(tip)}</div>`).join('')}
                                                </div>
                                                ${(portraitProfile.giftHints || []).length ? `<div class="portrait-tip-list" style="margin-top:12px;">${portraitProfile.giftHints.map((tip) => `<div class="portrait-tip">${escapeHtml(`送礼提示：${tip}`)}</div>`).join('')}</div>` : ''}
                                            </div>
                                        </div>
                                    ` : '<div class="empty-state">还没有这位联系人的人像分类结果。上传图片后切换到别的页面，系统会先请你确认再分析。</div>'}
                                </section>
                            ` : '<div class="empty-state">请先选择一个联系人会话。</div>'}
                        </div>
                    </div>
                </section>
            `;
            autoResizeMessageComposer();
        }

        function createAnalysis(targetId) {
            const targets = targetId === 'all'
                ? state.relationships
                : state.relationships.filter((item) => item.id === targetId);

            if (!targets.length) {
                showToast('请先新增至少一位关系对象，再生成分析。');
                return;
            }

            const averageIntimacy = Math.round(targets.reduce((sum, item) => sum + item.intimacy, 0) / targets.length);
            const averageWeekly = (targets.reduce((sum, item) => sum + Number(item.weeklyFrequency || 0), 0) / targets.length).toFixed(1);
            const averageDepth = (targets.reduce((sum, item) => sum + Number(item.monthlyDepth || 0), 0) / targets.length).toFixed(1);
            const averageGap = targets.reduce((sum, item) => sum + getCadenceGap(item) + getDepthGap(item), 0) / targets.length;
            const importantCount = targets.filter((item) => item.importanceTier === 'important').length;
            const portraitCount = targets.filter((item) => item.portraitProfile?.summary).length;
            const score = clamp(Math.round(averageIntimacy - averageGap * 7 + Number(averageWeekly) * 2 + importantCount * 2), 48, 96);
            const title = targetId === 'all' ? '全局关系频率分析' : `${targets[0].name} 的互动频率分析`;
            const focusNames = targets.slice(0, 2).map((item) => item.name).join('、');

            const report = {
                id: `analysis-${Date.now()}`,
                title,
                targetId,
                score,
                createdAt: formatDate(new Date()),
                summary: targetId === 'all'
                    ? `当前整体关系节奏处于 ${score >= 85 ? '稳定偏强' : score >= 70 ? '可继续优化' : '需要优先修复'} 区间，优先看重要关系里频率掉下来的对象。`
                    : `${targets[0].name} 这段关系目前 ${score >= 85 ? '维护得比较稳' : '存在轻微掉线风险'}，更适合围绕具体近况继续推进。`,
                insights: [
                    `${focusNames} 的当前关系强度平均值为 ${averageIntimacy}，说明这组关系 ${averageIntimacy >= 80 ? '基础较好' : '还有提升空间'}。`,
                    `当前平均每周交流 ${averageWeekly} 次、每月深聊 ${averageDepth} 次，系统会更看重这个频率，而不是手动标记。`,
                    importantCount
                        ? `这组关系里有 ${importantCount} 位被你标记为重要对象，排序会直接影响优先级。`
                        : '当前还没有标记重要层级，可以先把真正关键的人放进重要关系。',
                    portraitCount
                        ? `其中有 ${portraitCount} 位已经补充了人像档案，系统会把外在印象一起纳入沟通和礼物判断。`
                        : '当前还没有补充人像档案，消息页上传头像后可以进一步细化判断。',
                ],
                suggestions: targetId === 'all'
                    ? [
                        '先把重要关系中每周频次低于建议值的人拉回稳定节奏。',
                        '如果有生日临近对象，把礼物判断和联系动作提前安排。',
                        '优先做少量高质量互动，而不是对很多人同时浅聊。',
                    ]
                    : [
                        `优先围绕 ${targets[0].name} 最近的具体近况继续展开，而不是泛泛问候。`,
                        '如果当前周交流偏低，先用低打扰但具体的消息把节奏拉回来。',
                        '如果这是重要关系，优先保证持续频率，再考虑更深的推进动作。',
                    ],
            };

            state.analyses.unshift(report);
            state.ui.selectedAnalysisId = report.id;
            state.ui.analysisVisibleCount = ANALYSIS_RENDER_BATCH;
            if (targetId !== 'all') state.ui.assistantTargetId = targets[0].id;
            persistState();
            if (requestPageChange('analysis')) {
                showToast(`已生成：${report.title}`);
            }
        }

        function openRelationshipModal(id = null) {
            const relationship = state.relationships.find((item) => item.id === id);
            document.getElementById('relationship-form').reset();
            document.getElementById('relationship-id').value = relationship?.id || '';
            document.getElementById('relationship-name').value = relationship?.name || '';
            document.getElementById('relationship-type').value = relationship?.type || 'friend';
            document.getElementById('relationship-city').value = relationship?.city || '';
            document.getElementById('relationship-birthday').value = relationship?.birthday || '';
            document.getElementById('relationship-last-contact').value = relationship?.lastContact || formatDate(new Date());
            document.getElementById('relationship-tags').value = relationship?.tags?.join(',') || '';
            document.getElementById('relationship-note').value = relationship?.note || '';
            document.getElementById('relationship-weekly-frequency').value = relationship?.weeklyFrequency ?? 3;
            document.getElementById('relationship-weekly-frequency-value').textContent = `${relationship?.weeklyFrequency ?? 3} 次`;
            document.getElementById('relationship-monthly-depth').value = relationship?.monthlyDepth ?? 2;
            document.getElementById('relationship-monthly-depth-value').textContent = `${relationship?.monthlyDepth ?? 2} 次`;
            document.getElementById('relationship-importance-tier').value = relationship?.importanceTier || 'regular';
            document.getElementById('relationship-importance-rank').value = relationship?.importanceRank || 3;
            document.getElementById('relationship-importance-rank-value').textContent = relationship?.importanceRank || 3;
            updateRelationshipImportanceRankVisibility();
            document.getElementById('modal-title').textContent = relationship ? `编辑 ${relationship.name}` : '新增关系';
            document.getElementById('relationship-modal').classList.add('open');
            document.getElementById('relationship-modal').setAttribute('aria-hidden', 'false');
        }

        function saveRelationship(event) {
            event.preventDefault();
            const id = document.getElementById('relationship-id').value;
            const tier = document.getElementById('relationship-importance-tier').value;
            const existing = id ? findRelationshipById(id) : null;
            const relationship = normalizeRelationship({
                id: id || `rel-${Date.now()}`,
                name: document.getElementById('relationship-name').value.trim(),
                type: document.getElementById('relationship-type').value,
                city: document.getElementById('relationship-city').value.trim(),
                birthday: document.getElementById('relationship-birthday').value.trim(),
                lastContact: document.getElementById('relationship-last-contact').value || formatDate(new Date()),
                weeklyFrequency: Number(document.getElementById('relationship-weekly-frequency').value),
                monthlyDepth: Number(document.getElementById('relationship-monthly-depth').value),
                importanceTier: tier,
                importanceRank: tier === 'important'
                    ? Number(document.getElementById('relationship-importance-rank').value)
                    : 0,
                note: document.getElementById('relationship-note').value.trim(),
                tags: document.getElementById('relationship-tags').value.split(',').map((item) => item.trim()).filter(Boolean),
                portraitProfile: existing?.portraitProfile || null,
            });

            if (!relationship.name) {
                showToast('请先填写姓名。');
                return;
            }

            if (id) {
                const index = state.relationships.findIndex((item) => item.id === id);
                if (index !== -1) state.relationships[index] = relationship;
            } else {
                state.relationships.unshift(relationship);
            }

            state.ui.selectedRelationshipId = relationship.id;
            closeRelationshipModal();
            renderAll();
            showToast(`${relationship.name} 已按频率规则保存`);
        }

        function exportData() {
            const blob = new Blob([JSON.stringify(state, null, 2)], { type: 'application/json' });
            const url = URL.createObjectURL(blob);
            const link = document.createElement('a');
            link.href = url;
            link.download = `renmai-web-data-${formatDate(new Date())}.json`;
            link.click();
            URL.revokeObjectURL(url);
            showToast('已导出当前网页工作台数据');
        }

        function parseImportedState(rawText, fileName = '') {
            const payload = JSON.parse(rawText);
            if (payload && payload.format === 'renmai-web-bridge-v1' && payload.state && typeof payload.state === 'object') {
                const preservedTheme = sanitizeWebTheme(state.settings.webTheme);
                const preservedDensity = sanitizeWebDensity(state.settings.webDensity);
                const nextState = normalizeState(payload.state);
                nextState.bridge = normalizeBridge({
                    ...(nextState.bridge || {}),
                    source: 'desktop',
                    mode: 'desktop-to-web',
                    importedAt: String(payload.exported_at || nextState.bridge?.importedAt || ''),
                    fileName: fileName || String(nextState.bridge?.fileName || ''),
                    contactCount: Number(nextState.bridge?.contactCount || nextState.relationships.length || 0),
                    recordCount: Number(nextState.bridge?.recordCount || 0),
                    packageCount: Number(nextState.bridge?.packageCount || 0),
                    reportTitle: String(nextState.bridge?.reportTitle || ''),
                    reportUsedAi: Boolean(nextState.bridge?.reportUsedAi),
                });
                nextState.settings = {
                    ...nextState.settings,
                    webTheme: preservedTheme,
                    webDensity: preservedDensity,
                    webGuideDismissed: false,
                    journeyGuideDismissed: false,
                    relationshipGuideDismissed: false,
                    analysisGuideDismissed: false,
                    messageGuideDismissed: false,
                    giftGuideDismissed: false,
                };
                nextState.ui = {
                    ...nextState.ui,
                    activePage: 'dashboard',
                };
                return {
                    nextState,
                    successMessage: '已接收桌面端交接包，接下来先看总览和联系人。',
                };
            }

            return {
                nextState: normalizeState(payload),
                successMessage: '网页端数据导入成功',
            };
        }

        function importData(file) {
            if (!file) return;
            const reader = new FileReader();
            reader.onload = () => {
                try {
                    const imported = parseImportedState(String(reader.result || ''), file.name || '');
                    state = imported.nextState;
                    renderAll();
                    closeHandoffModal();
                    showToast(imported.successMessage);
                } catch (_) {
                    showToast('导入失败，请确认这是仁迈网页端导出的 JSON 或桌面端桥接包');
                }
            };
            reader.readAsText(file);
        }

        function resetDemo() {
            if (!window.confirm('确定恢复为演示数据吗？当前本地修改会被覆盖。')) return;
            state = normalizeState(cloneData(defaultState));
            state.settings.webGuideDismissed = false;
            state.settings.journeyGuideDismissed = false;
            state.settings.relationshipGuideDismissed = false;
            state.settings.analysisGuideDismissed = false;
            state.settings.messageGuideDismissed = false;
            state.settings.giftGuideDismissed = false;
            portraitReviewState = {
                candidate: null,
                pendingPage: null,
                analyzing: false,
            };
            closePortraitReviewModal();
            renderAll();
            showToast('已恢复演示数据');
        }

        function jumpToGifts(id) {
            const relationship = state.relationships.find((item) => item.id === id);
            if (!relationship) return;
            state.ui.giftRelation = relationship.type;
            state.ui.selectedGiftRelationshipId = relationship.id;
            state.ui.giftBudget = Math.max(state.ui.giftBudget, getGiftBudgetRecommendation(relationship, state.ui.giftOccasion).max);
            persistState();
            if (requestPageChange('gifts')) {
                showToast(`已切换到 ${relationship.name} 对应的礼物筛选`);
            }
        }

        function openAiAssistant(id) {
            const relationship = findRelationshipById(id);
            if (!relationship) return;
            state.ui.assistantTargetId = relationship.id;
            persistState();
            openAiTaskModal(relationship.id);
            showToast(`已打开 ${relationship.name} 的 AI 任务框`);
        }

        function applySuggestedGiftBudget() {
            const relationship = getSelectedGiftRelationship();
            if (!relationship) return;
            const budget = getGiftBudgetRecommendation(relationship, state.ui.giftOccasion);
            state.ui.giftBudget = budget.max;
            renderGifts();
            persistState();
            showToast(`已采用 ${relationship.name} 的建议预算 ${budget.label}`);
        }

        function toggleFavoriteGift(id) {
            if (state.favorites.includes(id)) {
                state.favorites = state.favorites.filter((item) => item !== id);
                renderAll();
                showToast('已取消收藏');
                return;
            }
            state.favorites.push(id);
            renderAll();
            showToast('已加入收藏');
        }

        function giftToAnalysis(id) {
            const gift = GIFT_CATALOG.find((item) => item.id === id);
            if (!gift) return;
            persistState();
            if (requestPageChange('analysis')) {
                showToast(`建议已记住：${gift.name} 适合 ${RELATION_LABELS[state.ui.giftRelation]}`);
            }
        }

        async function generateAiAssistant() {
            const target = findRelationshipById(state.ui.assistantTargetId);
            if (!target) {
                showToast('先选择一个联系人，再生成回应。');
                return;
            }

            aiPending = true;
            renderAnalysis();
            renderAiTaskModalContent();
            let result = null;
            let toastMessage = '';
            try {
                const payload = await fetchJson(buildAppUrl(AI_CHAT_ENDPOINT), {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify(buildAssistantApiPayload(target, state.ui.assistantScenario, state.ui.assistantIntent)),
                });
                result = normalizeAssistantApiResponse(payload, target, state.ui.assistantIntent);
                toastMessage = `已通过隐私代理生成 ${target.name} 的回应`;
            } catch (error) {
                console.error(error);
                result = buildLocalAssistantResponse(target, state.ui.assistantScenario, state.ui.assistantIntent);
                toastMessage = '云端回应暂时不可用，已切换到本地策略';
            } finally {
                aiPending = false;
                if (result) {
                    if (!result.budgetText) {
                        result.budgetText = `当前建议礼物价值：${getGiftBudgetRecommendation(target, state.ui.giftOccasion).label}`;
                    }
                    state.assistantHistory = [result, ...state.assistantHistory].slice(0, 12);
                    persistState();
                }
                renderAnalysis();
                renderAiTaskModalContent();
                if (toastMessage) showToast(toastMessage);
            }
        }

        async function copyAiReply() {
            const latest = getLatestAssistantRecordForTarget(state.ui.assistantTargetId);
            if (!latest?.reply) {
                showToast('当前还没有可复制的回应内容');
                return;
            }

            try {
                if (navigator.clipboard?.writeText) {
                    await navigator.clipboard.writeText(latest.reply);
                } else {
                    const textarea = document.createElement('textarea');
                    textarea.value = latest.reply;
                    document.body.appendChild(textarea);
                    textarea.select();
                    document.execCommand('copy');
                    textarea.remove();
                }
                showToast('已复制当前 AI 回复');
            } catch (_) {
                showToast('复制失败，请手动选中文本');
            }
        }

        function setCloudPortraitOptIn(enabled) {
            secretState.cloudPortraitOptIn = Boolean(enabled);
            persistSecretState();
            if (state.ui.activePage === 'profile') {
                renderProfile();
            }
            if (state.ui.activePage === 'messages') {
                renderMessages();
            }
        }

        async function rejectPortraitCandidate() {
            const relationshipName = portraitReviewState.candidate?.relationshipName || '当前联系人';
            const nextPage = portraitReviewState.pendingPage || 'messages';
            portraitReviewState.candidate = null;
            closePortraitReviewModal();
            if (requestPageChange(nextPage, { force: true })) {
                showToast(`已丢弃 ${relationshipName} 的待确认人像`);
            }
        }

        async function confirmPortraitCandidate() {
            const candidate = portraitReviewState.candidate;
            const nextPage = portraitReviewState.pendingPage || 'messages';
            const relationship = candidate ? findRelationshipById(candidate.relationshipId) : null;
            if (!candidate || !relationship) {
                portraitReviewState.candidate = null;
                closePortraitReviewModal();
                return;
            }
            portraitReviewState.analyzing = true;
            renderPortraitReviewBody();
            try {
                if (!secretState.cloudPortraitOptIn) {
                    const allowCloudPortrait = window.confirm('云端人像分析默认关闭。若继续启用，系统会先压缩并去除图片元数据，再通过同域隐私代理发送给云端视觉模型；如果你不同意，本次将只用本地规则分析。是否开启云端人像分析？');
                    if (allowCloudPortrait) {
                        setCloudPortraitOptIn(true);
                    }
                }
                const profile = await analyzePortraitCandidate(candidate, relationship);
                applyPortraitProfileToRelationship(relationship.id, profile);
                portraitReviewState.candidate = null;
                closePortraitReviewModal();
                requestPageChange(nextPage, { force: true });
                showToast(profile.source === 'model' ? `已为 ${relationship.name} 生成云端人像分类` : `已为 ${relationship.name} 生成本地人像分类`);
            } catch (error) {
                console.error(error);
                const profile = buildLocalPortraitProfile(candidate, relationship);
                applyPortraitProfileToRelationship(relationship.id, profile);
                portraitReviewState.candidate = null;
                closePortraitReviewModal();
                requestPageChange(nextPage, { force: true });
                showToast(`模型识别失败，已用本地规则为 ${relationship.name} 生成人像分类`);
            }
        }

        document.addEventListener('click', async (event) => {
            const button = event.target.closest('[data-action], [data-nav]');
            if (!button) return;

            if (button.dataset.nav) {
                const nextPage = AVAILABLE_PAGES.includes(button.dataset.nav) ? button.dataset.nav : 'dashboard';
                if (nextPage === 'messages' && state.ui.selectedRelationshipId) {
                    state.ui.selectedMessageRelationshipId = state.ui.selectedRelationshipId;
                }
                requestPageChange(nextPage);
                return;
            }

            switch (button.dataset.action) {
                case 'set-auth-mode':
                    setAuthMode(button.dataset.mode);
                    break;
                case 'submit-auth-form':
                    document.getElementById('auth-form')?.requestSubmit();
                    break;
                case 'enter-demo':
                    enterDemoAccount();
                    break;
                case 'reset-local-auth':
                    resetLocalAuthSession();
                    break;
                case 'open-reset-request':
                    setAuthMode('reset-request');
                    break;
                case 'open-ai-task-modal':
                    openAiTaskModal();
                    break;
                case 'close-ai-task-modal':
                    closeAiTaskModal();
                    break;
                case 'logout':
                    logout();
                    break;
                case 'open-add-modal':
                    openRelationshipModal();
                    break;
                case 'open-focus-relationship':
                    if (button.dataset.id) {
                        state.ui.selectedRelationshipId = button.dataset.id;
                    }
                    requestPageChange('relationships');
                    break;
                case 'open-focus-message':
                    if (button.dataset.id) {
                        state.ui.selectedRelationshipId = button.dataset.id;
                        state.ui.selectedMessageRelationshipId = button.dataset.id;
                    }
                    requestPageChange('messages');
                    break;
                case 'close-modal':
                    closeRelationshipModal();
                    break;
                case 'open-handoff-modal':
                    openHandoffModal();
                    break;
                case 'close-handoff-modal':
                    closeHandoffModal();
                    break;
                case 'set-relation-view':
                    state.ui.relationView = button.dataset.view;
                    renderRelationships();
                    persistState();
                    break;
                case 'set-relation-filter':
                    state.ui.relationFilter = button.dataset.filter;
                    state.ui.relationVisibleCount = RELATIONSHIP_RENDER_BATCH;
                    renderRelationships();
                    persistState();
                    break;
                case 'select-relationship':
                    state.ui.selectedRelationshipId = button.dataset.id;
                    renderRelationships();
                    persistState();
                    break;
                case 'select-message-thread':
                    state.ui.selectedMessageRelationshipId = button.dataset.id;
                    state.ui.selectedRelationshipId = button.dataset.id;
                    renderMessages();
                    persistState();
                    break;
                case 'show-more-message-threads':
                    state.ui.messageThreadVisibleCount = Math.max(
                        MESSAGE_THREAD_RENDER_BATCH,
                        Number(state.ui.messageThreadVisibleCount || MESSAGE_THREAD_RENDER_BATCH) + MESSAGE_THREAD_RENDER_BATCH,
                    );
                    renderMessages();
                    persistState();
                    break;
                case 'open-message-thread':
                    state.ui.selectedMessageRelationshipId = button.dataset.id;
                    state.ui.selectedRelationshipId = button.dataset.id;
                    requestPageChange('messages');
                    break;
                case 'show-more-relationships':
                    state.ui.relationVisibleCount = Math.max(
                        RELATIONSHIP_RENDER_BATCH,
                        Number(state.ui.relationVisibleCount || RELATIONSHIP_RENDER_BATCH) + RELATIONSHIP_RENDER_BATCH,
                    );
                    renderRelationships();
                    persistState();
                    break;
                case 'edit-relationship':
                    openRelationshipModal(button.dataset.id);
                    break;
                case 'delete-relationship':
                    deleteRelationship(button.dataset.id);
                    break;
                case 'confirm-portrait-candidate':
                    await confirmPortraitCandidate();
                    break;
                case 'reject-portrait-candidate':
                    await rejectPortraitCandidate();
                    break;
                case 'stay-on-messages':
                    closePortraitReviewModal();
                    requestPageChange('messages', { force: true });
                    break;
                case 'generate-analysis':
                    createAnalysis(button.dataset.targetId || 'all');
                    break;
                case 'generate-analysis-from-select': {
                    const select = document.getElementById('analysis-target');
                    createAnalysis(select ? select.value : 'all');
                    break;
                }
                case 'select-analysis':
                    state.ui.selectedAnalysisId = button.dataset.id;
                    renderAnalysis();
                    persistState();
                    break;
                case 'show-more-analyses':
                    state.ui.analysisVisibleCount = Math.max(
                        ANALYSIS_RENDER_BATCH,
                        Number(state.ui.analysisVisibleCount || ANALYSIS_RENDER_BATCH) + ANALYSIS_RENDER_BATCH,
                    );
                    renderAnalysis();
                    persistState();
                    break;
                case 'jump-to-gifts':
                    jumpToGifts(button.dataset.id);
                    break;
                case 'open-ai-assistant':
                    openAiAssistant(button.dataset.id);
                    break;
                case 'set-gift-relation':
                    state.ui.giftRelation = button.dataset.relation;
                    state.ui.selectedGiftRelationshipId = state.relationships.find((item) => item.type === button.dataset.relation)?.id || state.ui.selectedGiftRelationshipId;
                    renderGifts();
                    persistState();
                    break;
                case 'set-gift-occasion':
                    state.ui.giftOccasion = button.dataset.occasion;
                    renderGifts();
                    persistState();
                    break;
                case 'toggle-favorite-gift':
                    toggleFavoriteGift(button.dataset.id);
                    break;
                case 'gift-to-analysis':
                    giftToAnalysis(button.dataset.id);
                    break;
                case 'apply-gift-budget':
                    applySuggestedGiftBudget();
                    break;
                case 'generate-ai-assistant':
                    generateAiAssistant();
                    break;
                case 'generate-ai-task-reply':
                    await generateAiAssistant();
                    break;
                case 'copy-ai-reply':
                    copyAiReply();
                    break;
                case 'copy-ai-task-reply':
                    await copyAiReply();
                    break;
                case 'save-manual-message':
                    addManualMessage();
                    break;
                case 'draft-to-ai-task':
                    moveDraftToAiTask();
                    break;
                case 'trigger-portrait-upload':
                    document.getElementById('portrait-upload-input')?.click();
                    break;
                case 'refresh-api-health':
                    await refreshServiceHealth();
                    break;
                case 'export-data':
                    exportData();
                    break;
                case 'import-data':
                    document.getElementById('import-file').click();
                    break;
                case 'reset-demo':
                    resetDemo();
                    break;
                case 'set-web-theme':
                    setWebTheme(button.dataset.theme);
                    break;
                case 'set-web-density':
                    setWebDensity(button.dataset.density);
                    break;
                case 'dismiss-web-guide':
                    dismissWebGuide();
                    break;
                case 'reopen-web-guide':
                    reopenWebGuide();
                    break;
                case 'dismiss-journey-guide':
                    dismissJourneyGuide();
                    break;
                case 'reopen-journey-guide':
                    reopenJourneyGuide();
                    break;
                case 'dismiss-page-guide':
                    dismissPageGuide(button.dataset.guide);
                    break;
                case 'reopen-page-guide':
                    reopenPageGuide(button.dataset.guide);
                    break;
                default:
                    break;
            }
        });

        document.addEventListener('input', (event) => {
            if (event.target.id === 'relationship-search') {
                const cursor = event.target.selectionStart;
                const selectionEnd = event.target.selectionEnd;
                state.ui.relationSearch = event.target.value;
                state.ui.relationVisibleCount = RELATIONSHIP_RENDER_BATCH;
                scheduleRelationshipRender(cursor, selectionEnd);
                persistState();
            }

            if (event.target.id === 'gift-budget') {
                state.ui.giftBudget = Number(event.target.value);
                scheduleGiftRender();
                persistState();
            }

            if (event.target.id === 'assistant-scenario') {
                state.ui.assistantScenario = event.target.value;
                persistState();
            }

            if (event.target.id === 'ai-task-scenario') {
                state.ui.assistantScenario = event.target.value;
                persistState();
            }

            if (event.target.id === 'message-composer') {
                const relationship = getSelectedMessageRelationship();
                if (!relationship) return;
                setMessageDraft(relationship.id, event.target.value);
                autoResizeMessageComposer();
                persistState();
            }

            if (event.target.id === 'relationship-weekly-frequency') {
                document.getElementById('relationship-weekly-frequency-value').textContent = `${event.target.value} 次`;
            }

            if (event.target.id === 'relationship-monthly-depth') {
                document.getElementById('relationship-monthly-depth-value').textContent = `${event.target.value} 次`;
            }

            if (event.target.id === 'relationship-importance-rank') {
                document.getElementById('relationship-importance-rank-value').textContent = event.target.value;
            }
        });

        document.addEventListener('keydown', (event) => {
            if (event.target.id === 'message-composer' && event.key === 'Enter' && !event.shiftKey) {
                event.preventDefault();
                addManualMessage();
            }
        });

        document.addEventListener('change', (event) => {
            if (event.target.matches('[data-setting-key]')) {
                state.settings[event.target.dataset.settingKey] = event.target.checked;
                renderAll();
                showToast('设置已更新');
            }

            if (event.target.id === 'import-file') {
                importData(event.target.files[0]);
                event.target.value = '';
            }

            if (event.target.id === 'portrait-upload-input') {
                const [file] = event.target.files || [];
                if (file) {
                    queuePortraitCandidate(file).catch((error) => {
                        console.error(error);
                        showToast('图片读取失败，请换一张图片再试');
                    });
                }
                event.target.value = '';
            }

            if (event.target.id === 'gift-target') {
                const relationship = findRelationshipById(event.target.value);
                if (!relationship) return;
                state.ui.selectedGiftRelationshipId = relationship.id;
                state.ui.giftRelation = relationship.type;
                renderGifts();
                persistState();
            }

            if (event.target.id === 'assistant-target') {
                state.ui.assistantTargetId = event.target.value;
                renderAnalysis();
                persistState();
            }

            if (event.target.id === 'ai-task-target') {
                state.ui.assistantTargetId = event.target.value;
                renderAiTaskModalContent();
                persistState();
            }

            if (event.target.id === 'assistant-intent') {
                state.ui.assistantIntent = event.target.value;
                renderAnalysis();
                persistState();
            }

            if (event.target.id === 'ai-task-intent') {
                state.ui.assistantIntent = event.target.value;
                renderAiTaskModalContent();
                persistState();
            }

            if (event.target.id === 'cloud-portrait-opt-in') {
                setCloudPortraitOptIn(event.target.checked);
                showToast(event.target.checked ? '已开启云端人像分析' : '已切回本地人像分析');
            }

            if (event.target.id === 'relationship-importance-tier') {
                updateRelationshipImportanceRankVisibility();
            }
        });

        document.addEventListener('submit', (event) => {
            if (event.target.id === 'auth-form') {
                submitAuthForm(event);
            }

            if (event.target.id === 'relationship-form') {
                saveRelationship(event);
            }

            if (event.target.id === 'profile-form') {
                event.preventDefault();
                const form = new FormData(event.target);
                state.profile = {
                    name: String(form.get('name') || '').trim(),
                    title: String(form.get('title') || '').trim(),
                    city: String(form.get('city') || '').trim(),
                    phone: String(form.get('phone') || '').trim(),
                    bio: String(form.get('bio') || '').trim(),
                };
                renderAll();
                persistState();
                showToast('资料已保存');
            }
        });

        document.getElementById('relationship-modal').addEventListener('click', (event) => {
            if (event.target.id === 'relationship-modal') {
                closeRelationshipModal();
            }
        });

        document.getElementById('portrait-review-modal').addEventListener('click', (event) => {
            if (event.target.id === 'portrait-review-modal' && !portraitReviewState.analyzing) {
                closePortraitReviewModal();
                requestPageChange('messages', { force: true });
            }
        });

        document.getElementById('ai-task-modal').addEventListener('click', (event) => {
            if (event.target.id === 'ai-task-modal' && !aiPending) {
                closeAiTaskModal();
            }
        });

        if (typeof window !== 'undefined' && typeof window.addEventListener === 'function') {
            window.addEventListener('hashchange', () => {
                const hashPage = getPageFromHash();
                if (!hashPage || hashPage === state.ui.activePage) return;
                const changed = requestPageChange(hashPage);
                if (!changed) {
                    syncHashToPage();
                }
            });
            window.addEventListener('pagehide', () => {
                flushPersistState();
            });
            window.addEventListener('beforeunload', () => {
                flushPersistState();
            });
            window.addEventListener('resize', () => {
                scheduleTopbarMotionNavSync(state.ui.activePage);
            });
        }

        bindTopbarMotionNav();
        applyHashPage();
        renderAll();
        if (typeof document !== 'undefined' && document.fonts?.ready) {
            document.fonts.ready.then(() => {
                scheduleTopbarMotionNavSync(state.ui.activePage);
            }).catch(() => {
                // ignore
            });
        }
        void refreshServiceHealth({ silent: true });
