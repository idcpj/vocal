/**
 * Vocal Official Website - Modern Interactive Engine
 * iOS · Android · macOS · Windows
 */

document.addEventListener('DOMContentLoaded', () => {

  // =========================================================================
  // 1. Navbar, Scroll Progress & Mobile Drawer
  // =========================================================================
  const navbar = document.getElementById('navbar');
  const scrollProgress = document.getElementById('scroll-progress');
  const menuToggle = document.getElementById('menu-toggle');
  const mobileDrawer = document.getElementById('mobile-drawer');

  window.addEventListener('scroll', () => {
    const scrollTop = window.scrollY;
    const docHeight = document.documentElement.scrollHeight - window.innerHeight;
    const progress = docHeight > 0 ? (scrollTop / docHeight) * 100 : 0;
    
    if (scrollProgress) {
      scrollProgress.style.width = `${progress}%`;
    }

    if (scrollTop > 30) {
      navbar.classList.add('scrolled');
    } else {
      navbar.classList.remove('scrolled');
    }
  });

  if (menuToggle && mobileDrawer) {
    menuToggle.addEventListener('click', () => {
      mobileDrawer.classList.toggle('open');
    });

    document.querySelectorAll('.mobile-nav-link').forEach(link => {
      link.addEventListener('click', () => {
        mobileDrawer.classList.remove('open');
      });
    });
  }

  // Smooth scroll for all anchor links
  document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', function(e) {
      const targetId = this.getAttribute('href');
      if (targetId && targetId !== '#') {
        const targetElem = document.querySelector(targetId);
        if (targetElem) {
          e.preventDefault();
          const navOffset = navbar ? navbar.offsetHeight + 10 : 80;
          const elementPosition = targetElem.getBoundingClientRect().top + window.scrollY;
          window.scrollTo({
            top: elementPosition - navOffset,
            behavior: 'smooth'
          });
        }
      }
    });
  });

  // =========================================================================
  // 2. Cursor Follower Glow Effect
  // =========================================================================
  const cursorGlow = document.getElementById('cursor-glow');
  let mouseX = window.innerWidth / 2;
  let mouseY = window.innerHeight / 2;
  let currentX = mouseX;
  let currentY = mouseY;

  if (cursorGlow && window.matchMedia('(pointer: fine)').matches) {
    window.addEventListener('mousemove', (e) => {
      mouseX = e.clientX;
      mouseY = e.clientY;
    });

    function animateCursorGlow() {
      currentX += (mouseX - currentX) * 0.12;
      currentY += (mouseY - currentY) * 0.12;
      cursorGlow.style.left = `${currentX}px`;
      cursorGlow.style.top = `${currentY}px`;
      requestAnimationFrame(animateCursorGlow);
    }
    requestAnimationFrame(animateCursorGlow);
  } else if (cursorGlow) {
    cursorGlow.style.display = 'none';
  }

  // =========================================================================
  // 3. Interactive Fluid Audio Waveform Canvas (Hero Canvas)
  // =========================================================================
  const waveCanvas = document.getElementById('hero-soundwave');
  let waveIntensity = 1.0;
  let targetIntensity = 1.0;

  if (waveCanvas) {
    const ctx = waveCanvas.getContext('2d');
    let width, height;
    let step = 0;

    function resizeCanvas() {
      width = waveCanvas.offsetWidth;
      height = waveCanvas.offsetHeight;
      const dpr = window.devicePixelRatio || 1;
      waveCanvas.width = width * dpr;
      waveCanvas.height = height * dpr;
      ctx.scale(dpr, dpr);
    }

    window.addEventListener('resize', resizeCanvas);
    resizeCanvas();

    function drawWave() {
      ctx.clearRect(0, 0, width, height);

      // Smooth intensity interpolation
      waveIntensity += (targetIntensity - waveIntensity) * 0.08;

      const waves = [
        { color: 'rgba(34, 211, 238, 0.45)', speed: 0.035, frequency: 0.008, amplitude: 22 * waveIntensity, offset: 0 },
        { color: 'rgba(59, 130, 246, 0.35)', speed: 0.025, frequency: 0.012, amplitude: 16 * waveIntensity, offset: Math.PI / 2 },
        { color: 'rgba(139, 92, 246, 0.30)', speed: 0.018, frequency: 0.006, amplitude: 28 * waveIntensity, offset: Math.PI },
        { color: 'rgba(6, 182, 212, 0.70)', speed: 0.045, frequency: 0.015, amplitude: 12 * waveIntensity, offset: Math.PI * 1.5 }
      ];

      waves.forEach(w => {
        ctx.beginPath();
        ctx.strokeStyle = w.color;
        ctx.lineWidth = 2.2;
        ctx.lineCap = 'round';

        for (let x = 0; x <= width; x += 3) {
          const y = height / 2 +
            Math.sin(x * w.frequency + step * w.speed + w.offset) * w.amplitude *
            Math.sin(x / width * Math.PI); // Pin ends to zero for a natural wave look

          if (x === 0) {
            ctx.moveTo(x, y);
          } else {
            ctx.lineTo(x, y);
          }
        }
        ctx.stroke();
      });

      step += 1;
      requestAnimationFrame(drawWave);
    }
    requestAnimationFrame(drawWave);
  }

  // =========================================================================
  // 4. Interactive Simulation Playground
  // =========================================================================
  const draftBox = document.getElementById('sim-draft-box');
  const draftCharCount = document.getElementById('draft-char-count');
  const btnToggleMic = document.getElementById('btn-toggle-mic');
  const micStatusText = document.getElementById('mic-status-text');
  const btnSendMac = document.getElementById('btn-send-mac');
  const btnClearDraft = document.getElementById('btn-clear-draft');
  const simStatusTip = document.getElementById('sim-status-tip');
  const simAutoEnter = document.getElementById('sim-auto-enter');
  const simLang = document.getElementById('sim-lang');
  const payloadPreview = document.getElementById('payload-preview');
  const dataPacket = document.getElementById('data-packet');
  const simLatencyVal = document.getElementById('sim-latency-val');
  const statInjectedChars = document.getElementById('stat-injected-chars');
  const statSavedSeconds = document.getElementById('stat-saved-seconds');
  const appTabs = document.querySelectorAll('.app-tab, .app-pill-btn');
  const appViews = document.querySelectorAll('.app-view, .mac-app-view');
  const activeAppTitle = document.getElementById('active-app-title');

  // Stats Counters
  let totalCharsInjected = 0;
  let totalSavedSeconds = 0;
  let isRecording = false;
  let speechRecognizer = null;
  let simulatedTypingTimer = null;

  // Initialize Speech Recognition if supported
  const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
  if (SpeechRecognition) {
    try {
      speechRecognizer = new SpeechRecognition();
      speechRecognizer.continuous = true;
      speechRecognizer.interimResults = true;

      speechRecognizer.onresult = (event) => {
        let currentSpeech = '';
        for (let i = event.resultIndex; i < event.results.length; ++i) {
          currentSpeech += event.results[i][0].transcript;
        }
        if (currentSpeech) {
          updateDraft(currentSpeech);
          targetIntensity = 2.8; // Burst audio wave
        }
      };

      speechRecognizer.onerror = (err) => {
        console.warn('Web Speech API Error / Fallback to Simulator:', err);
        stopRealRecording();
      };

      speechRecognizer.onend = () => {
        if (isRecording) {
          stopRealRecording();
        }
      };
    } catch (e) {
      console.warn('SpeechRecognition initialization error:', e);
    }
  }

  // Update Draft Helper
  function updateDraft(text) {
    if (!draftBox) return;
    draftBox.value = text;
    updateDraftMeta();
  }

  function updateDraftMeta() {
    if (!draftBox) return;
    const len = draftBox.value.length;
    if (draftCharCount) {
      draftCharCount.textContent = `${len} 字`;
    }

    if (payloadPreview) {
      const payloadObj = {
        type: "text_append",
        text: draftBox.value,
        enter: simAutoEnter ? simAutoEnter.checked : true,
        lang: simLang ? simLang.value : "zh-CN",
        timestamp: Date.now()
      };
      payloadPreview.textContent = JSON.stringify(payloadObj, null, 2);
    }
  }

  if (draftBox) {
    draftBox.addEventListener('input', updateDraftMeta);
  }

  if (simAutoEnter) {
    simAutoEnter.addEventListener('change', updateDraftMeta);
  }

  if (simLang) {
    simLang.addEventListener('change', () => {
      showToast(`识别语言已切换为: ${simLang.options[simLang.selectedIndex].text}`);
      updateDraftMeta();
    });
  }

  // Clear Draft
  if (btnClearDraft) {
    btnClearDraft.addEventListener('click', () => {
      if (simulatedTypingTimer) clearInterval(simulatedTypingTimer);
      updateDraft('');
      if (simStatusTip) simStatusTip.textContent = '草稿已清空';
      targetIntensity = 1.0;
    });
  }

  // Preset Phrases
  document.querySelectorAll('.phrase-chip, .chip-phrase').forEach(chip => {
    chip.addEventListener('click', () => {
      const phrase = chip.getAttribute('data-phrase');
      if (!phrase) return;

      if (simulatedTypingTimer) clearInterval(simulatedTypingTimer);

      if (simStatusTip) simStatusTip.textContent = '正在由预设短语转录生成...';
      targetIntensity = 2.4;

      // Simulate streaming transcription effect
      let charIndex = 0;
      updateDraft('');
      simulatedTypingTimer = setInterval(() => {
        if (charIndex < phrase.length) {
          charIndex++;
          updateDraft(phrase.slice(0, charIndex));
        } else {
          clearInterval(simulatedTypingTimer);
          if (simStatusTip) simStatusTip.textContent = '听写完成！请点击“发送到 Mac”注入';
          targetIntensity = 1.2;
          btnSendMac?.classList.add('glow-btn');
        }
      }, 35);
    });
  });

  // Toggle Microphone
  if (btnToggleMic) {
    btnToggleMic.addEventListener('click', () => {
      if (!isRecording) {
        startRecording();
      } else {
        stopRecording();
      }
    });
  }

  function startRecording() {
    isRecording = true;
    btnToggleMic.classList.add('recording');
    if (micStatusText) micStatusText.textContent = '正在录音...再次点击停止';
    if (simStatusTip) simStatusTip.textContent = '🎙️ 麦克风采集中 · 智能降噪中';
    targetIntensity = 2.6;

    if (speechRecognizer) {
      try {
        speechRecognizer.lang = simLang ? simLang.value : 'zh-CN';
        speechRecognizer.start();
        return;
      } catch (e) {
        console.warn('SpeechRecognition failed to start directly, using simulation:', e);
      }
    }

    // Fallback Simulated Recording
    const sampleSentences = [
      "Vocal 将我的 iPhone 瞬间变成 Mac 高速语音输入键盘，体验非常顺畅！",
      "今天在 VS Code 中编写 Python 异步通信模块，输入效率直接翻倍。",
      "局域网 WebSocket 极速直连传输延迟小于 15 毫秒，零云端中转隐私安全。",
      "利用 Apple 原生听写引擎与端侧神经网络，精准识别每一个字符！"
    ];
    const sentence = sampleSentences[Math.floor(Math.random() * sampleSentences.length)];

    let idx = 0;
    updateDraft('');
    simulatedTypingTimer = setInterval(() => {
      if (idx < sentence.length && isRecording) {
        idx++;
        updateDraft(sentence.slice(0, idx));
        targetIntensity = 2.2 + Math.random() * 0.8;
      } else {
        stopRecording();
      }
    }, 60);
  }

  function stopRecording() {
    isRecording = false;
    btnToggleMic.classList.remove('recording');
    if (micStatusText) micStatusText.textContent = '点击开始录音';
    if (simStatusTip) simStatusTip.textContent = '听写已结束 · 草稿可编辑修改';
    targetIntensity = 1.0;

    if (simulatedTypingTimer) {
      clearInterval(simulatedTypingTimer);
    }

    stopRealRecording();
  }

  function stopRealRecording() {
    if (speechRecognizer) {
      try {
        speechRecognizer.stop();
      } catch (e) {}
    }
  }

  // App Switcher
  const appTitles = {
    vscode: 'workspace/vocal — VS Code (AI Agent)',
    notes: '灵感便签 — 2026年11月13日 (Apple Notes)',
    chat: '团队协作通讯 (Slack / WeChat)'
  };

  appTabs.forEach(tab => {
    tab.addEventListener('click', () => {
      appTabs.forEach(t => t.classList.remove('active'));
      appViews.forEach(v => v.classList.remove('active'));

      tab.classList.add('active');
      const appKey = tab.getAttribute('data-app');
      const targetView = document.getElementById(`view-${appKey}`);
      if (targetView) targetView.classList.add('active');
      if (activeAppTitle && appTitles[appKey]) {
        activeAppTitle.textContent = appTitles[appKey];
      }
    });
  });

  // Send to Mac Action
  if (btnSendMac) {
    btnSendMac.addEventListener('click', () => {
      const textToSend = draftBox ? draftBox.value.trim() : '';

      if (!textToSend) {
        showToast('请先录入语音或选择预设短语再发送');
        if (draftBox) draftBox.focus();
        return;
      }

      // 1. Data Packet Animation across LAN Pipeline
      if (dataPacket) {
        dataPacket.classList.remove('fly');
        // Force reflow
        void dataPacket.offsetWidth;
        dataPacket.classList.add('fly');
      }

      // Randomize realistic latency between 9ms and 14ms
      const randomLatency = Math.floor(Math.random() * 6) + 9;
      if (simLatencyVal) {
        simLatencyVal.textContent = `~${randomLatency}ms`;
      }

      // 2. Host Target App Injection with Typing Effect
      const activeTab = document.querySelector('.app-tab.active, .app-pill-btn.active');
      const activeApp = activeTab ? activeTab.getAttribute('data-app') : 'vscode';
      const shouldEnter = simAutoEnter ? simAutoEnter.checked : true;

      injectTextIntoApp(activeApp, textToSend, shouldEnter);

      // 3. Efficiency Stats Calculation
      const textLen = textToSend.length;
      totalCharsInjected += textLen;
      // Manual typing average: 3.5 chars/sec -> saved approx 0.28s per char
      const savedSecs = Math.round(textLen * 0.28);
      totalSavedSeconds += savedSecs;

      if (statInjectedChars) statInjectedChars.textContent = totalCharsInjected;
      if (statSavedSeconds) statSavedSeconds.textContent = totalSavedSeconds;

      // 4. Reset Mobile Draft
      if (simStatusTip) simStatusTip.textContent = `已成功注入 (${randomLatency}ms)！`;
      showToast(`⚡ 文本已极速注入到电脑活跃窗口 (延迟 ${randomLatency}ms)`);
      updateDraft('');
      targetIntensity = 1.0;
    });
  }

  // Inject into Host Application Views
  function injectTextIntoApp(appKey, text, enter) {
    if (appKey === 'vscode') {
      const inputTarget = document.getElementById('vscode-injected-content');
      const inputShell = document.getElementById('vscode-agent-input-container');

      if (inputShell) inputShell.classList.add('typing');

      if (inputTarget) {
        inputTarget.innerHTML = '';
        let i = 0;
        const typeTimer = setInterval(() => {
          if (i < text.length) {
            inputTarget.innerHTML = `<span>${escapeHtml(text.slice(0, i + 1))}</span><span class="cursor-blink">|</span>`;
            i++;
          } else {
            clearInterval(typeTimer);
            if (inputShell) inputShell.classList.remove('typing');

            if (enter) {
              // 自动回车：模拟瞬间敲下 Enter 提交给 Agent
              setTimeout(() => {
                submitPromptToAgent(text);
              }, 260);
            } else {
              inputTarget.innerHTML = `<span>${escapeHtml(text)}</span><span class="cursor-blink">|</span>`;
            }
          }
        }, 14);
      }
    } else if (appKey === 'notes') {
      const notesTarget = document.getElementById('notes-injected-content');
      if (notesTarget) {
        const newParagraph = document.createElement('p');
        newParagraph.className = 'injected-note-p';
        newParagraph.textContent = `• ${text}${enter ? ' ↵' : ''}`;
        notesTarget.appendChild(newParagraph);
      }
    } else if (appKey === 'chat') {
      const chatInput = document.getElementById('chat-input-text');
      const chatContainer = document.getElementById('chat-messages-box');

      if (chatInput) {
        chatInput.innerHTML = `<span style="color:#22D3EE;">${escapeHtml(text)}</span>`;
      }

      if (enter && chatContainer) {
        setTimeout(() => {
          const newBubble = document.createElement('div');
          newBubble.className = 'chat-bubble right';
          newBubble.innerHTML = `
            <div class="chat-avatar">我</div>
            <div class="chat-bubble-text">${escapeHtml(text)}</div>
          `;
          chatContainer.appendChild(newBubble);
          chatContainer.scrollTop = chatContainer.scrollHeight;

          if (chatInput) {
            chatInput.innerHTML = `<span class="chat-placeholder">等待来自手机的键盘字符注入...</span><span class="cursor-blink">|</span>`;
          }
        }, 400);
      }
    }
  }

  // VS Code AI Agent: Submit Prompt & Generate Mock Code Response
  function submitPromptToAgent(promptText) {
    const inputTarget = document.getElementById('vscode-injected-content');
    const messagesContainer = document.getElementById('vscode-agent-messages');
    if (!messagesContainer) return;

    // 1. Append User Message Bubble
    const userRow = document.createElement('div');
    userRow.className = 'agent-msg-row user';
    userRow.innerHTML = `
      <div class="agent-avatar user">我</div>
      <div class="agent-msg-content">
        <div class="agent-bubble user">${escapeHtml(promptText)}</div>
      </div>
    `;
    messagesContainer.appendChild(userRow);
    messagesContainer.scrollTop = messagesContainer.scrollHeight;

    // 2. Reset Agent Input Box
    if (inputTarget) {
      inputTarget.innerHTML = `<span class="agent-placeholder">向 Agent 提问或让其编写代码（点击左侧“发送”注入）...</span>`;
    }

    // 3. Agent Generates Code Response
    setTimeout(() => {
      const codeSnippet = generateAgentCodeSnippet(promptText);
      const assistantRow = document.createElement('div');
      assistantRow.className = 'agent-msg-row assistant';
      assistantRow.innerHTML = `
        <div class="agent-avatar">🤖</div>
        <div class="agent-msg-content">
          <div class="agent-bubble">
            <div style="color:var(--accent-cyan);font-weight:600;font-size:0.75rem;margin-bottom:0.35rem;">⚡ 代码已由 Agent 实时生成：</div>
            <div class="agent-code-card">
              <div class="agent-code-head">
                <span>main.py (Generated)</span>
                <span>Python 3.12</span>
              </div>
              <pre class="agent-code-body"><code>${escapeHtml(codeSnippet)}</code></pre>
            </div>
          </div>
        </div>
      `;
      messagesContainer.appendChild(assistantRow);
      messagesContainer.scrollTop = messagesContainer.scrollHeight;
    }, 320);
  }

  function generateAgentCodeSnippet(prompt) {
    if (prompt.includes('并发') || prompt.includes('网络') || prompt.includes('Python')) {
      return `import asyncio\nimport aiohttp\n\nasync def fetch_worker(session, url):\n    async with session.get(url) as resp:\n        return await resp.json()\n\nasync def main():\n    async with aiohttp.ClientSession() as s:\n        tasks = [fetch_worker(s, f"https://api.lan/node/{i}") for i in range(10)]\n        results = await asyncio.gather(*tasks)\n    print("All tasks completed gracefully.")`;
    } else if (prompt.includes('死锁') || prompt.includes('锁') || prompt.includes('排查')) {
      return `from threading import Lock\n\n# 采用锁排序规避循环等待死锁\nmutex_a, mutex_b = Lock(), Lock()\n\ndef safe_transfer():\n    first, second = sorted([mutex_a, mutex_b], key=id)\n    with first:\n        with second:\n            print("Acquired locks in deterministic order.")`;
    } else if (prompt.includes('UI') || prompt.includes('暗黑') || prompt.includes('界面')) {
      return `/* 极简暗黑毛玻璃科技面板 */\n.vocal-panel {\n  background: rgba(10, 15, 28, 0.85);\n  backdrop-filter: blur(20px);\n  border: 1px solid rgba(34, 211, 238, 0.3);\n  box-shadow: 0 0 25px rgba(34, 211, 238, 0.15);\n}`;
    } else {
      return `async def handle_vocal_stream(stream):\n    async for chunk in stream:\n        await process_payload(chunk)\n    print("Stream processed with zero cloud latency.")`;
    }
  }

  // Manual Agent Submit Button
  const btnAgentSubmit = document.getElementById('btn-agent-submit');
  if (btnAgentSubmit) {
    btnAgentSubmit.addEventListener('click', () => {
      const inputTarget = document.getElementById('vscode-injected-content');
      if (inputTarget) {
        const text = inputTarget.textContent.replace('向 Agent 提问或让其编写代码（点击左侧“发送”注入）...', '').replace('|', '').trim();
        if (text) {
          submitPromptToAgent(text);
        }
      }
    });
  }

  function escapeHtml(str) {
    return str
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#039;");
  }

  // =========================================================================
  // 5. Download Center Tabs Switching
  // =========================================================================
  const dlTabs = document.querySelectorAll('.dl-tab-btn, .dl-pill-btn');
  const dlPanes = document.querySelectorAll('.dl-tab-pane, .dl-panel');

  dlTabs.forEach(tab => {
    tab.addEventListener('click', () => {
      dlTabs.forEach(t => t.classList.remove('active'));
      dlPanes.forEach(p => p.classList.remove('active'));

      tab.classList.add('active');
      const targetPaneId = `pane-${tab.getAttribute('data-tab')}`;
      const targetPane = document.getElementById(targetPaneId);
      if (targetPane) {
        targetPane.classList.add('active');
      }
    });
  });

  // Handle cross-links directly activating download tabs (e.g. #download-mac)
  function checkUrlHashTab() {
    const hash = window.location.hash;
    if (hash === '#download-mac') {
      (document.querySelector('[data-tab="dl-mac"]') || document.querySelector('[data-tab="mac"]'))?.click();
    } else if (hash === '#download-win') {
      (document.querySelector('[data-tab="dl-win"]') || document.querySelector('[data-tab="win"]'))?.click();
    } else if (hash === '#download-ios') {
      (document.querySelector('[data-tab="dl-ios"]') || document.querySelector('[data-tab="ios"]'))?.click();
    } else if (hash === '#download-android') {
      (document.querySelector('[data-tab="dl-android"]') || document.querySelector('[data-tab="android"]'))?.click();
    }
  }

  window.addEventListener('hashchange', checkUrlHashTab);
  checkUrlHashTab();

  // =========================================================================
  // 6. Terminal Copy Buttons
  // =========================================================================
  document.querySelectorAll('.copy-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      const codeTargetId = btn.getAttribute('data-target');
      const targetElem = document.getElementById(codeTargetId);
      if (!targetElem) return;

      const textToCopy = targetElem.innerText || '';
      if (textToCopy) {
        navigator.clipboard.writeText(textToCopy.trim()).then(() => {
          showToast('命令已成功复制到剪贴板！');
          const originalHTML = btn.innerHTML;
          btn.innerHTML = `<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"></polyline></svg> 已复制`;
          btn.style.color = 'var(--cyan-bright)';
          setTimeout(() => {
            btn.innerHTML = originalHTML;
            btn.style.color = '';
          }, 2200);
        }).catch(err => {
          console.error('Copy failed:', err);
        });
      }
    });
  });

  // =========================================================================
  // 7. FAQ Accordion
  // =========================================================================
  const faqItems = document.querySelectorAll('.faq-item, .faq-row');
  faqItems.forEach(item => {
    const question = item.querySelector('.faq-question, .faq-row-q');
    if (question) {
      question.addEventListener('click', () => {
        const isActive = item.classList.contains('active');
        faqItems.forEach(i => i.classList.remove('active'));
        if (!isActive) {
          item.classList.add('active');
        }
      });
    }
  });

  // =========================================================================
  // 8. Toast Notification Utility
  // =========================================================================
  const toast = document.getElementById('toast');
  let toastTimer = null;

  function showToast(message) {
    if (!toast) return;
    const msgElem = toast.querySelector('.toast-msg');
    if (msgElem) msgElem.textContent = message;

    toast.classList.add('show');
    if (toastTimer) clearTimeout(toastTimer);

    toastTimer = setTimeout(() => {
      toast.classList.remove('show');
    }, 2800);
  }

  // =========================================================================
  // 9. Cyber Gallery Tabs & Lightbox Fullscreen Preview
  // =========================================================================
  const galleryTabs = document.querySelectorAll('.gallery-tab-btn');
  const galleryCards = document.querySelectorAll('.gallery-card[data-cat]');
  const lightbox = document.getElementById('cyber-lightbox');
  const lightboxImg = document.getElementById('lightbox-img');
  const lightboxCaption = document.getElementById('lightbox-caption');
  const lightboxClose = document.getElementById('lightbox-close');
  const lightboxBackdrop = document.getElementById('lightbox-backdrop');

  // Filter Tabs
  galleryTabs.forEach(tab => {
    tab.addEventListener('click', () => {
      galleryTabs.forEach(t => t.classList.remove('active'));
      tab.classList.add('active');
      const filter = tab.getAttribute('data-filter');

      galleryCards.forEach(card => {
        const cat = card.getAttribute('data-cat');
        if (filter === 'all' || cat === filter) {
          card.classList.remove('hidden');
        } else {
          card.classList.add('hidden');
        }
      });
    });
  });

  // Lightbox Preview
  document.querySelectorAll('.gallery-img-wrap[data-lightbox]').forEach(wrap => {
    wrap.addEventListener('click', () => {
      const src = wrap.getAttribute('data-lightbox');
      const cap = wrap.getAttribute('data-caption') || '画板全屏透视';
      if (lightbox && lightboxImg && lightboxCaption) {
        lightboxImg.src = src;
        lightboxCaption.textContent = cap;
        lightbox.classList.add('open');
        lightbox.setAttribute('aria-hidden', 'false');
        document.body.style.overflow = 'hidden';
      }
    });
  });

  function closeLightbox() {
    if (lightbox) {
      lightbox.classList.remove('open');
      lightbox.setAttribute('aria-hidden', 'true');
      document.body.style.overflow = '';
    }
  }

  lightboxClose?.addEventListener('click', closeLightbox);
  lightboxBackdrop?.addEventListener('click', closeLightbox);

  window.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && lightbox?.classList.contains('open')) {
      closeLightbox();
    }
  });

  // Keyboard shortcut for quick sending in playground: Cmd/Ctrl + Enter
  window.addEventListener('keydown', (e) => {
    if ((e.metaKey || e.ctrlKey) && e.key === 'Enter') {
      if (document.activeElement === draftBox || document.getElementById('playground')?.contains(document.activeElement)) {
        e.preventDefault();
        btnSendMac?.click();
      }
    }
  });

});
