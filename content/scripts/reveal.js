const defaultChapter = "frontpage";
const chapters = document.getElementsByClassName("chapter")
let currentChapterId = defaultChapter;

function selectChapterId(id) {
  let node = document.getElementById(id);

  while (node && !node.classList.contains("chapter")) {
    node = node.parentNode;
  }

  if (!node) {
    id = defaultChapter;
    node = document.getElementById(id);
  }

  currentChapterId = node.id;

  for (const chap of chapters) {
    chap.classList.add("hidden");
  }

  node.classList.remove("hidden");
}

function selectChapter(node) {
  selectChapterId(node.id);
  window.location.hash = "#" + node.id;
}

function update() {
  window.location.hash ||= "#" + currentChapterId;
  selectChapterId(window.location.hash.substring(1));
}

function chapterIndex() {
  let i = 0;
  while (chapters[i].id != currentChapterId) {
    i++;
  }
  return i;
}

function previousPage() {
  const i = chapterIndex();
  if (i <= 0 || i >= chapters.length) {
    return
  }

  selectChapter(chapters[i-1]);
}

function nextPage() {
  const i = chapterIndex();
  if (i < 0 || i >= (chapters.length-1)) {
    return
  }

  selectChapter(chapters[i+1]);
}

window.onload = update;
window.onhashchange = update;
