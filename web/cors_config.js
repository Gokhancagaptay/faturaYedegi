// CORS configuration for web
window.addEventListener('DOMContentLoaded', function() {
  // Add CORS headers for Firebase Storage images
  const meta = document.createElement('meta');
  meta.httpEquiv = 'Content-Security-Policy';
  meta.content = "img-src 'self' data: https://storage.googleapis.com https://firebasestorage.googleapis.com;";
  document.head.appendChild(meta);
});
