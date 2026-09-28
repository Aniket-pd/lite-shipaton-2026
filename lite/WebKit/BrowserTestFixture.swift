#if DEBUG
import Foundation

/// Deterministic UI coverage, enabled only with BOTH UI-test launch arguments.
/// Never used by a normal launch or included in a Release build.
enum BrowserTestFixture {
    static let discoverHTML = """
    <!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"><title>Example</title>
    <style>
    :root { color-scheme:light dark; font:17px -apple-system; background:light-dark(#f8f6ef,#20231f); color:light-dark(#252820,#f1f0e8); }
    body { margin:0; padding:24px 24px 90px; }
    header { font:28px Georgia; margin-bottom:32px; }
    small { font:12px -apple-system; letter-spacing:2px; }
    h1 { font:38px/1.1 Georgia; letter-spacing:-1px; }
    p { line-height:1.6; }
    .art { height:160px; background:linear-gradient(155deg,#abc0c3,#d5d6b4 48%,#7a8b6c 49%,#475648); border-radius:4px; }
    footer { position:fixed; bottom:0; left:0; right:0; padding:8px 20px; background:light-dark(#f8f6ef,#20231f); border-top:1px solid #8885; }
    button { font:16px -apple-system; min-height:44px; padding:8px 16px; color:inherit; background:transparent; border:1px solid #8888; border-radius:12px; }
    </style></head><body><header>Journal.</header><small>Website preview</small>
    <h1>A quieter way to see the world.</h1><p>Notes on places, people, and the small things worth noticing.</p>
    <div class="art"></div><h2>The pleasure of slowing down</h2><p>Take a moment to look around.</p>
    <footer><button onclick="this.textContent='Page state preserved'">Keep my place</button></footer>
    </body></html>
    """

    static let immersiveHTML = """
    <!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1">
    <meta name="theme-color" content="#ff7700">
    <style>
    :root { background:#0b1015; color:#f4f4f4; font:18px -apple-system; }
    :root.light { background:#f8f5ee; color:#171717; }
    body { margin:0; background:inherit; }
    header { position:fixed; top:0; left:0; right:0; padding:14px 20px; background:inherit; font-size:24px; z-index:1; }
    main { padding:64px 20px 90px; line-height:1.65; }
    article { padding:20px 0; border-bottom:1px solid #7777; }
    h1 { font:36px Georgia; margin:12px 0; }
    .art { height:180px; background:linear-gradient(155deg,#658891,#ddb596 48%,#3d575b 49%,#192f37); border-radius:12px; }
    footer { position:fixed; bottom:0; left:0; right:0; background:inherit; border-top:1px solid #7777; display:flex; gap:8px; padding:8px 12px; }
    button,input { font:16px -apple-system; min-height:44px; border:1px solid #777; border-radius:9px; background:transparent; color:inherit; }
    input { width:0; min-width:0; flex:1; padding:0 10px; }
    #scheme { font-size:14px; }
    </style></head><body>
    <header>Journal</header><main><h1>A quieter way to see the world</h1>
    <p id="scheme"></p><div class="art"></div>
    <p>Notes from a slower journey through places, people, and ordinary moments.</p>
    <div id="articles"></div></main>
    <footer><button onclick="document.documentElement.classList.toggle('light')">Change page color</button><input aria-label="Write a note" placeholder="Write a note"></footer>
    <script>
    const scheme = matchMedia('(prefers-color-scheme: dark)');
    function updateScheme() { document.getElementById('scheme').textContent = 'Website preference: ' + (scheme.matches ? 'dark' : 'light'); }
    scheme.addEventListener('change', updateScheme); updateScheme();
    document.getElementById('articles').innerHTML = Array.from({length:20},(_,i)=>'<article><h2>Moment '+(i+1)+'</h2><p>There is a certain kind of freedom in moving slowly. Notice the light, the people and the details along the way.</p></article>').join('');
    </script></body></html>
    """

    /// The same article without a sticky footer exercises real content underlap.
    static let underlapHTML = immersiveHTML.replacingOccurrences(
        of: "</head>",
        with: "<style>footer{display:none}main{background:repeating-linear-gradient(#142d36 0 180px,#31454a 180px 360px)}</style></head>"
    )

    static let html = """
    <!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"><title>Browser fixture</title></head>
    <body style="font:18px -apple-system;padding:20px">
      <h1>Browser fixture</h1>
      <p><label for="note">Your note</label><input id="note" style="font-size:18px" value="Keep my place"></p>
      <p><label for="upload">Upload a file</label><input id="upload" type="file" onchange="document.getElementById('result').textContent=this.files[0]?.name||'No file'"></p>
      <p><button onclick="document.getElementById('result').textContent='Download requested';try {const a=document.createElement('a');a.href=window.URL.createObjectURL(new Blob(['Lite fixture download'],{type:'text/plain'}));a.download='lite-fixture.txt';document.body.appendChild(a);a.click();document.getElementById('result').textContent='Download link clicked '+a.href.split(':')[0];}catch(e){document.getElementById('result').textContent=e.name+': '+e.message;}">Download file</button></p>
      <p><a href="about:blank" target="_blank">Open window</a></p>
      <p><a href="https://doubleclick.net/advert" target="_blank">Open ad window</a></p>
      <p><button onclick="location.replace('https://doubleclick.net/advert')">Ad redirect</button></p>
      <p><button onclick="const w=window.open('about:blank');if(w){w.document.write('<html><meta name=viewport content=width=device-width><body><h1>Website window</h1><a href=about:blank target=_blank>Nested window</a></body></html>');w.document.close();}">Open written window</button></p>
      <div class="ad-banner">Fixture advertisement</div>
      <div role="dialog">Useful website content</div>
      <p><button onclick="alert('Fixture message')">Show dialog</button></p>
      <p><button onclick="localStorage.setItem('lite-ui-test','stored');document.cookie='lite_ui_test=stored;path=/;SameSite=Lax;Secure';document.getElementById('result').textContent='Stored website data';">Store website data</button></p>
      <p id="result">No file</p>
    </body></html>
    """
}
#endif
