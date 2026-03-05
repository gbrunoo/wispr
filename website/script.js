// Smooth scroll behavior for anchor links
document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', function (e) {
        e.preventDefault();
        const target = document.querySelector(this.getAttribute('href'));
        if (target) {
            target.scrollIntoView({
                behavior: 'smooth',
                block: 'start'
            });
        }
    });
});

// Fetch latest release from GitHub
async function fetchLatestRelease() {
    try {
        const response = await fetch('https://api.github.com/repos/sebsto/wispr/releases/latest');
        const data = await response.json();
        
        const downloadLink = document.getElementById('download-link');
        const downloadText = document.getElementById('download-text');
        const versionInfo = document.getElementById('version-info');
        const footerDownloadLink = document.querySelector('.footer-links a[href*="releases"]');
        
        if (data.assets && data.assets.length > 0) {
            // Find the .dmg or .pkg file
            const asset = data.assets.find(a => a.name.endsWith('.dmg') || a.name.endsWith('.pkg')) || data.assets[0];
            const downloadUrl = asset.browser_download_url;
            
            // Update main download button
            downloadLink.href = downloadUrl;
            downloadText.textContent = `Download ${data.tag_name}`;
            versionInfo.textContent = `Latest: ${data.tag_name} • ${(asset.size / 1024 / 1024).toFixed(1)} MB`;
            
            // Update footer download link
            if (footerDownloadLink) {
                footerDownloadLink.href = downloadUrl;
            }
        } else {
            downloadLink.href = data.html_url;
            downloadText.textContent = `View ${data.tag_name} on GitHub`;
            versionInfo.textContent = `Latest: ${data.tag_name}`;
            
            if (footerDownloadLink) {
                footerDownloadLink.href = data.html_url;
            }
        }
    } catch (error) {
        console.error('Failed to fetch latest release:', error);
        const downloadLink = document.getElementById('download-link');
        const versionInfo = document.getElementById('version-info');
        const footerDownloadLink = document.querySelector('.footer-links a[href*="releases"]');
        
        const fallbackUrl = 'https://github.com/sebsto/wispr/releases/latest';
        downloadLink.href = fallbackUrl;
        versionInfo.textContent = 'View releases on GitHub';
        
        if (footerDownloadLink) {
            footerDownloadLink.href = fallbackUrl;
        }
    }
}

// Copy to clipboard functionality
document.querySelectorAll('.copy-btn').forEach(btn => {
    btn.addEventListener('click', async function() {
        const textToCopy = this.getAttribute('data-copy');
        try {
            await navigator.clipboard.writeText(textToCopy);
            const originalText = this.textContent;
            this.textContent = 'Copied!';
            setTimeout(() => {
                this.textContent = originalText;
            }, 2000);
        } catch (err) {
            console.error('Failed to copy:', err);
        }
    });
});

// Call on page load
fetchLatestRelease();

// Intersection Observer for fade-in animations
const observerOptions = {
    threshold: 0.2,
    rootMargin: '0px 0px -100px 0px'
};

const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
        if (entry.isIntersecting) {
            entry.target.classList.add('visible');
        }
    });
}, observerOptions);

// Observe all feature cards, steps, and use cases
document.querySelectorAll('.feature-card, .step, .use-case, .screenshot-item').forEach(el => {
    el.style.opacity = '0';
    el.style.transform = 'translateY(30px)';
    el.style.transition = 'opacity 0.6s ease, transform 0.6s ease';
    observer.observe(el);
});

// Add visible class styling
const style = document.createElement('style');
style.textContent = `
    .visible {
        opacity: 1 !important;
        transform: translateY(0) !important;
    }
`;
document.head.appendChild(style);

// Add staggered animation delays
document.querySelectorAll('.feature-card').forEach((card, index) => {
    card.style.transitionDelay = `${index * 0.1}s`;
});

document.querySelectorAll('.step').forEach((step, index) => {
    step.style.transitionDelay = `${index * 0.15}s`;
});

document.querySelectorAll('.use-case').forEach((useCase, index) => {
    useCase.style.transitionDelay = `${index * 0.1}s`;
});

document.querySelectorAll('.screenshot-item').forEach((item, index) => {
    item.style.transitionDelay = `${index * 0.15}s`;
});

// Onboarding Carousel
let currentSlide = 0;
const slides = document.querySelectorAll('.onboarding-slide');
const totalSlides = slides.length;
const track = document.querySelector('.carousel-track');
const dotsContainer = document.querySelector('.carousel-dots');
const prevBtn = document.querySelector('.carousel-btn.prev');
const nextBtn = document.querySelector('.carousel-btn.next');

// Create dots
for (let i = 0; i < totalSlides; i++) {
    const dot = document.createElement('button');
    dot.classList.add('carousel-dot');
    if (i === 0) dot.classList.add('active');
    dot.setAttribute('aria-label', `Go to slide ${i + 1}`);
    dot.addEventListener('click', () => goToSlide(i));
    dotsContainer.appendChild(dot);
}

const dots = document.querySelectorAll('.carousel-dot');

function updateCarousel() {
    const slideWidth = slides[0].offsetWidth;
    const gap = 32; // 2rem gap
    const offset = currentSlide * (slideWidth + gap);
    track.style.transform = `translateX(-${offset}px)`;
    
    // Update dots
    dots.forEach((dot, index) => {
        dot.classList.toggle('active', index === currentSlide);
    });
    
    // Update button states
    prevBtn.disabled = currentSlide === 0;
    nextBtn.disabled = currentSlide === totalSlides - 1;
}

function goToSlide(index) {
    currentSlide = Math.max(0, Math.min(index, totalSlides - 1));
    updateCarousel();
}

function nextSlide() {
    if (currentSlide < totalSlides - 1) {
        currentSlide++;
        updateCarousel();
    }
}

function prevSlide() {
    if (currentSlide > 0) {
        currentSlide--;
        updateCarousel();
    }
}

prevBtn.addEventListener('click', prevSlide);
nextBtn.addEventListener('click', nextSlide);

// Keyboard navigation for carousel
document.addEventListener('keydown', (e) => {
    const carousel = document.querySelector('.onboarding-carousel');
    if (!carousel) return;
    
    const rect = carousel.getBoundingClientRect();
    const isInView = rect.top >= 0 && rect.bottom <= window.innerHeight;
    
    if (isInView) {
        if (e.key === 'ArrowLeft') {
            e.preventDefault();
            prevSlide();
        } else if (e.key === 'ArrowRight') {
            e.preventDefault();
            nextSlide();
        }
    }
});

// Auto-advance carousel (optional)
let autoAdvanceInterval;
function startAutoAdvance() {
    autoAdvanceInterval = setInterval(() => {
        if (currentSlide < totalSlides - 1) {
            nextSlide();
        } else {
            currentSlide = 0;
            updateCarousel();
        }
    }, 5000);
}

function stopAutoAdvance() {
    clearInterval(autoAdvanceInterval);
}

// Start auto-advance when carousel is in view
const carouselObserver = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
        if (entry.isIntersecting) {
            startAutoAdvance();
        } else {
            stopAutoAdvance();
        }
    });
}, { threshold: 0.5 });

const carousel = document.querySelector('.onboarding-carousel');
if (carousel) {
    carouselObserver.observe(carousel);
    
    // Stop auto-advance on user interaction
    carousel.addEventListener('click', stopAutoAdvance);
    carousel.addEventListener('touchstart', stopAutoAdvance);
}

// Update carousel on window resize
window.addEventListener('resize', updateCarousel);

// Hide scroll indicator when user scrolls
let scrollTimeout;
const scrollIndicator = document.querySelector('.scroll-indicator');

window.addEventListener('scroll', () => {
    if (scrollIndicator && window.scrollY > 100) {
        scrollIndicator.style.opacity = '0';
        scrollIndicator.style.pointerEvents = 'none';
    } else if (scrollIndicator) {
        scrollIndicator.style.opacity = '0.7';
        scrollIndicator.style.pointerEvents = 'auto';
    }
});

// Parallax effect for hero background
window.addEventListener('scroll', () => {
    const hero = document.querySelector('.hero');
    if (hero) {
        const scrolled = window.scrollY;
        const heroHeight = hero.offsetHeight;
        if (scrolled < heroHeight) {
            hero.style.transform = `translateY(${scrolled * 0.5}px)`;
            hero.style.opacity = 1 - (scrolled / heroHeight) * 0.5;
        }
    }
});

// Add loading animation
window.addEventListener('load', () => {
    document.body.style.opacity = '0';
    document.body.style.transition = 'opacity 0.5s ease';
    setTimeout(() => {
        document.body.style.opacity = '1';
    }, 100);
});

// Keyboard navigation for sections
document.addEventListener('keydown', (e) => {
    const sections = document.querySelectorAll('.section');
    const currentSection = Array.from(sections).findIndex(section => {
        const rect = section.getBoundingClientRect();
        return rect.top >= -100 && rect.top <= 100;
    });

    if (e.key === 'ArrowDown' && currentSection < sections.length - 1) {
        e.preventDefault();
        sections[currentSection + 1].scrollIntoView({ behavior: 'smooth' });
    } else if (e.key === 'ArrowUp' && currentSection > 0) {
        e.preventDefault();
        sections[currentSection - 1].scrollIntoView({ behavior: 'smooth' });
    }
});
