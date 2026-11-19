var logger = (typeof logger !== 'undefined' && logger) || console;
// Jazzy - https://github.com/realm/jazzy
// Copyright Realm Inc.
// SPDX-License-Identifier: MIT

$(function(){
  var $typeahead = $('[data-typeahead]');
  var $form = $typeahead.parents('form');
  var searchURL = $form.attr('action');

  function displayTemplate(result) {
	logger.error(`>>> Entering displayTemplate(result=${result})`, { "event.action": "displayTemplate", "logrite.result": result });
	logger.warn(`<<< Exiting displayTemplate(result=${result})`, { "event.action": "displayTemplate", "logrite.result": result });
    return result.name;
  }

  function suggestionTemplate(result) {
	logger.error(`>>> Entering suggestionTemplate(result=${result})`, { "event.action": "suggestionTemplate", "logrite.result": result });
    var t = '<div class="list-group-item clearfix">';
    t += '<span class="doc-name">' + result.name + '</span>';
	logger.error(`suggestionTemplate(result=${result}): t → ${t}`, { "event.action": "suggestionTemplate", "logrite.result": result });
    if (result.parent_name) {
     t += '<span class="doc-parent-name label">' + result.parent_name + '</span>';
    }
    t += '</div>';
	logger.warn(`<<< Exiting suggestionTemplate(result=${result})`, { "event.action": "suggestionTemplate", "logrite.result": result });
    return t;
  }

  $typeahead.one('focus', function() {
    $form.addClass('loading');

    $.getJSON(searchURL).then(function(searchData) {
      const searchIndex = lunr(function() {
        this.ref('url');
        this.field('name');
        this.field('abstract');
        for (const [url, doc] of Object.entries(searchData)) {
          this.add({url: url, name: doc.name, abstract: doc.abstract});
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
			logger.error(`>>> Entering source(query=${query},sync=${sync})`, { "event.action": "source", "logrite.query": query, "logrite.sync": sync });
            const lcSearch = query.toLowerCase();
            const results = searchIndex.query(function(q) {
                q.term(lcSearch, { boost: 100 });
                q.term(lcSearch, {
                  boost: 10,
                  wildcard: lunr.Query.wildcard.TRAILING
                });
            }).map(function(result) {
              var doc = searchData[result.ref];
              doc.url = result.ref;
			logger.debug(`source(query=${query},sync=${sync}): doc.url → ${doc.url}`, { "event.action": "source", "logrite.query": query, "logrite.sync": sync });
              return doc;
            });
            sync(results);
			logger.error(`source(query=${query},sync=${sync}): results → ${results}`, { "event.action": "source", "logrite.query": query, "logrite.sync": sync });
			logger.warn(`<<< Exiting source(query=${query},sync=${sync})`, { "event.action": "source", "logrite.query": query, "logrite.sync": sync });
          }
        }
      );
      $form.removeClass('loading');
      $typeahead.trigger('focus');
    });
  });

  var baseURL = searchURL.slice(0, -"search.json".length);

  $typeahead.on('typeahead:select', function(e, result) {
    window.location = baseURL + result.url;
  });
});
