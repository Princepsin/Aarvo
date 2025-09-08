// Paste this into CodePen's JS panel (script.js)
(function(){
  // Helper: generate a short unique device code
  function genDeviceCode(){
    const S = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    const make = (n)=>Array.from({length:n}, ()=>S[Math.floor(Math.random()*S.length)]).join('');
    return `${make(4)}-${make(4)}`;
  }

  // Example suggestions dataset (videos, music, images, articles, wiki, history)
  const seed = [
    {type:'video', title:'Top 10 Travel Spots', desc:'Short travel guide video — 3:20'},
    {type:'music', title:'Chill Beats Mix', desc:'Background music playlist, 40m'},
    {type:'image', title:'Aurora Photos', desc:'Gallery of northern lights'},
    {type:'article', title:'How to Explore Offline', desc:'Tips to search when offline'},
    {type:'wikipedia', title:'History of Navigation', desc:'Wikipedia style summary'},
    {type:'history', title:'Recent Searches', desc:'Your saved search history demo'}
  ];

  // State
  let items = [];
  let loadedPages = 0;
  let selectedIndex = -1;

  // DOM
  const deviceCodeEl = document.getElementById('deviceCode');
  const suggestionsEl = document.getElementById('suggestions');
  const loaderEl = document.getElementById('loader');
  const searchInput = document.getElementById('searchInput');
  const searchBtn = document.getElementById('searchBtn');
  const prevBtn = document.getElementById('prevBtn');
  const nextBtn = document.getElementById('nextBtn');
  const bgServices = document.getElementById('bgServices');

  // set device code
  deviceCodeEl.textContent = 'Code: ' + genDeviceCode();

  // function to create more items (simulate server / offline pool)
  function loadMore(){
    // if background services turned off, show message and stop
    if(!bgServices.checked){
      loaderEl.textContent = 'Background services off — enable to load more.';
      return;
    }
    loaderEl.textContent = 'Loading…';
    // simulate creating 6 new items
    const newItems = [];
    for(let i=0;i<6;i++){
      const base = seed[(loadedPages*6 + i) % seed.length];
      newItems.push({
        type: base.type,
        title: `${base.title} ${loadedPages*6 + i + 1}`,
        desc: base.desc
      });
    }
    items = items.concat(newItems);
    renderList(items);
    loadedPages++;
    loaderEl.textContent = 'Scroll down to load more…';
  }

  // render the list (filteredItems optional)
  function renderList(list){
    suggestionsEl.innerHTML = '';
    list.forEach((it, idx)=>{
      const card = document.createElement('article');
      card.className = 'card' + (idx === selectedIndex ? ' selected' : '');
      card.dataset.index = idx;
      card.innerHTML = `
        <div class="thumb">${it.type[0].toUpperCase()}</div>
        <div class="meta">
          <div class="type">${it.type}</div>
          <div class="title">${escapeHtml(it.title)}</div>
          <div class="desc">${escapeHtml(it.desc)}</div>
        </div>
      `;
      card.addEventListener('click', ()=>{
        selectIndex(parseInt(card.dataset.index,10));
      });
      suggestionsEl.appendChild(card);
    });
  }

  function escapeHtml(s){
    return s.replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":"&#39;"}[c]));
  }

  function selectIndex(i){
    if(i < 0 || i >= items.length) return;
    selectedIndex = i;
    // highlight selected
    const cards = suggestionsEl.querySelectorAll('.card');
    cards.forEach(c=>c.classList.remove('selected'));
    const el = suggestionsEl.querySelector(`.card[data-index="${i}"]`);
    if(el) el.classList.add('selected');
    // scroll into view
    el && el.scrollIntoView({behavior:'smooth', block:'center'});
  }

  // search function: filter by title/type/desc
  function doSearch(q){
    q = q.trim().toLowerCase();
    if(!q){ renderList(items); return; }
    const filtered = items.filter(it => (it.title + ' ' + it.desc + ' ' + it.type).toLowerCase().includes(q));
    renderList(filtered);
    // reset selection
    selectedIndex = -1;
  }

  // previous / next navigation (cycles within full items list)
  function prevItem(){
    if(items.length === 0) return;
    if(selectedIndex <= 0) selectIndex(items.length - 1);
    else selectIndex(selectedIndex - 1);
  }
  function nextItem(){
    if(items.length === 0) return;
    if(selectedIndex >= items.length - 1) selectIndex(0);
    else selectIndex(selectedIndex + 1);
  }

  // lazy load on scroll (main container)
  const mainEl = document.querySelector('main');
  mainEl.addEventListener('scroll', ()=>{
    const nearBottom = mainEl.scrollTop + mainEl.clientHeight >= mainEl.scrollHeight - 120;
    if(nearBottom) loadMore();
  });

  // on initial load: load 2 pages for content
  loadMore();
  loadMore();

  // events
  searchBtn.addEventListener('click', ()=>doSearch(searchInput.value));
  searchInput.addEventListener('keyup', (e) => {
    if(e.key === 'Enter') doSearch(searchInput.value);
  });
  prevBtn.addEventListener('click', prevItem);
  nextBtn.addEventListener('click', nextItem);

  // when background services toggled, adjust loader message
  bgServices.addEventListener('change', ()=>{
    if(bgServices.checked) loaderEl.textContent = 'Background services enabled — scroll to load more';
    else loaderEl.textContent = 'Background services off — no new content';
  });

  // small helper: if page not scrollable (e.g. CodePen preview), hook window scroll too
  window.addEventListener('scroll', ()=>{
    const sc = document.scrollingElement || document.documentElement;
    if(sc.scrollTop + window.innerHeight >= sc.scrollHeight - 120) loadMore();
  });

})();