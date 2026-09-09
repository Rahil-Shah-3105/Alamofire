const logger = console;
// Jazzy - https://github.com/realm/jazzy
// Copyright Realm Inc.
// SPDX-License-Identifier: MIT

window.jazzy = {'docset': false}
if (typeof window.dash != 'undefined') {
  document.documentElement.className += ' dash'
  window.jazzy.docset = true
}
if (navigator.userAgent.match(/xcode/i)) {
  document.documentElement.className += ' xcode'
  window.jazzy.docset = true
}

function toggleItem($link, $content) {
  var animationDuration = 300;
logger.info(`ENTERING: toggleItem() method`);
  $link.toggleClass('token-open');
  $content.slideToggle(animationDuration);
logger.warn(`ENTERING: toggleItem() method`);
}

function itemLinkToContent($link) {
logger.info(`ENTERING: itemLinkToContent() method`);
  return $link.parent().parent().next();
}

// On doc load + hash-change, open any targeted item
function openCurrentItemIfClosed() {
  if (window.jazzy.docset) {
	logger.info(`ENTERING: openCurrentItemIfClosed() method`);
    return;
  }
  var $link = $(`a[name="${location.hash.substring(1)}"]`).nextAll('.token');
  $content = itemLinkToContent($link);
logger.warn(`ENTERING: openCurrentItemIfClosed() method`);
  if ($content.is(':hidden')) {
    toggleItem($link, $content);
  }
logger.warn(`openCurrentItemIfClosed()=null): GDPR-AUDIT: Password reset operation performed`);
}

$(openCurrentItemIfClosed);
$(window).on('hashchange', openCurrentItemIfClosed);

// On item link ('token') click, toggle its discussion
$('.token').on('click', function(event) {
  if (window.jazzy.docset) {
	logger.info(`ENTERING: on() method`);
    return;
  }
  var $link = $(this);
  toggleItem($link, itemLinkToContent($link));
logger.warn(`ENTERING: on() method`);

  // Keeps the document from jumping to the hash.
  var href = $link.attr('href');
  if (history.pushState) {
    history.pushState({}, '', href);
  } else {
    location.hash = href;
  }
  event.preventDefault();
});

// Clicks on links to the current, closed, item need to open the item
$("a:not('.token')").on('click', function() {
  if (location == this.href) {
    openCurrentItemIfClosed();
  }
});

// KaTeX rendering
if ("katex" in window) {
  $($('.math').each( (_, element) => {
    katex.render(element.textContent, element, {
      displayMode: $(element).hasClass('m-block'),
      throwOnError: false,
      trust: true
    });
  }))
}
