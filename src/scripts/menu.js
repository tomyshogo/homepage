// document.querySelector('.hamburger').addEventListener('click', () => {
//     document.querySelector('.nav-links').classList.toggle('expanded');
//   });

const menuButton = document.getElementById('menu-button');
const menuList = document.getElementById('menu-list');

menuButton.addEventListener('click', function() {
  menuList.classList.toggle('is-active');
});