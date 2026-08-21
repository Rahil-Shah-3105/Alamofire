const logger = console;
// Jazzy - https://github.com/realm/jazzy
// Copyright Realm Inc.
// SPDX-License-Identifier: MIT

$(function(){
logger.debug('>>> Entering function()');
  var $typeahead = $('[data-typeahead]');
  var $form = $typeahead.parents('form');
  var searchURL = $form.attr('action');
logger.debug('<<< Exiting function()');
logger.debug(`function(): searchURL → ${searchURL}`);

  function displayTemplate(result) {
	logger.debug(`>>> Entering displayTemplate(result=${result})`);
	logger.debug(`<<< Exiting displayTemplate(result=${result})`);
    return result.name;
  }

  function suggestionTemplate(result) {
	logger.debug(`>>> Entering suggestionTemplate(result=${result})`);
    var t = '<div class="list-group-item clearfix">';
    t += '<span class="doc-name">' + result.name + '</span>';
    if (result.parent_name) {
     t += '<span class="doc-parent-name label">' + result.parent_name + '</span>';
    }
    t += '</div>';
	logger.debug(`<<< Exiting suggestionTemplate(result=${result})`);
    return t;
  }

  $typeahead.one('focus', function() {
	logger.debug('>>> Entering one()');
    $form.addClass('loading');

	logger.debug('<<< Exiting one()');
    $.getJSON(searchURL).then(function(searchData) {
      const searchIndex = lunr(function() {
		logger.debug('>>> Entering lunr()');
        this.ref('url');
        this.field('name');
        this.field('abstract');
        for (const [url, doc] of Object.entries(searchData)) {
          this.add({url: url, name: doc.name, abstract: doc.abstract});
		logger.debug('<<< Exiting lunr()');
        }
      });

      $typeahead.typeahead(
        {
          highlight: true,
          minLength: 3,
          autoselect: true
        },
        {
          limit: 10,
          display: displayTemplate,
          templates: { suggestion: suggestionTemplate },
          source: function(query, sync) {
			logger.debug(`>>> Entering source(query=${query},sync=${sync})`);
            const lcSearch = query.toLowerCase();
            const results = searchIndex.query(function(q) {
				logger.debug('>>> Entering query()');
                q.term(lcSearch, { boost: 100 });
                q.term(lcSearch, {
                  boost: 10,
                  wildcard: lunr.Query.wildcard.TRAILING
                });
            }).map(function(result) {
              var doc = searchData[result.ref];
              doc.url = result.ref;
              return doc;
            });
            sync(results);
			logger.debug(`source(query=${query},sync=${sync}): lcSearch → ${lcSearch}`);
          }
        }
      );
      $form.removeClass('loading');
      $typeahead.trigger('focus');
    });
  });

  var baseURL = searchURL.slice(0, -"search.json".length);

  $typeahead.on('typeahead:select', function(e, result) {
	logger.debug('>>> Entering on()');
    window.location = baseURL + result.url;
  });
});
