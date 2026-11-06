// Vocal Official Landing Page Script

document.addEventListener('DOMContentLoaded', () => {
  // ─── Navbar Glassmorphism on Scroll ───
  const navbar = document.querySelector('.navbar');
  window.addEventListener('scroll', () => {
    if (window.scrollY > 40) {
      navbar.style.background = 'rgba(8, 12, 20, 0.95)';
      navbar.style.boxShadow = '0 10px 30px rgba(0, 0, 0, 0.5)';
    } else {
      navbar.style.background = 'rgba(8, 12, 20, 0.8)';
      navbar.style.boxShadow = 'none';
    }
  });

  // ─── FAQ Accordion ───
  const faqItems = document.querySelectorAll('.faq-item');
  faqItems.forEach(item => {
    const question = item.querySelector('.faq-question');
    question.addEventListener('click', () => {
      const isActive = item.classList.contains('active');
      faqItems.forEach(i => i.classList.remove('active'));
      if (!isActive) {
        item.classList.add('active');
      }
    });
  });

  // ─── Code Copy Buttons ───
  const copyButtons = document.querySelectorAll('.copy-btn');
  const toast = document.getElementById('toast');

  copyButtons.forEach(btn => {
    btn.addEventListener('click', () => {
      const codeTarget = btn.getAttribute('data-target');
      const textToCopy = document.getElementById(codeTarget)?.innerText || '';
      
      if (textToCopy) {
        navigator.clipboard.writeText(textToCopy.trim()).then(() => {
          showToast('命令已复制到剪贴板！');
          btn.innerHTML = `<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="20 6 9 17 4 12"></polyline></svg> 已复制`;
          setTimeout(() => {
            btn.innerHTML = `<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="9" y="9" width="13" height="13" rx="2" ry="2"></rect><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"></path></svg> 复制`;
          }, 2000);
        });
      }
    });
  });

  function showToast(message) {
    if (!toast) return;
    toast.querySelector('.toast-msg').textContent = message;
    toast.classList.add('show');
    setTimeout(() => {
      toast.classList.remove('show');
    }, 2500);
  }
});
