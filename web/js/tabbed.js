/**
 * @fileOverview
 * This file deals with tabbed panes.  It implements dynamic tabs on top
 * if Bootstrap.
 *
 * @version 0.2.0
 * @author Jan Wielemaker, J.Wielemaker@vu.nl
 * @requires jquery
 */

define([ "jquery", "laconic" ],
       function() {

(function($) {
  var pluginName = 'tabbed';
  var tabid = 0;

  /** @lends $.fn.tabbed */
  var methods = {
    /**
     * Turn the current element into a Bootstrap tabbed pane. All
     * children of the current element are changed into tabs.  The
     * child can control the mapping using:
     *
     *   - `data-label = "Label"`
     *   - `data-close = "disabled"`
     */
    _init: function(options) {
      return this.each(function() {
	var elem = $(this);
	var data = {};			/* private data */

	elem.addClass("tabbed");
	elem.tabbed('makeTabbed');

	elem.data(pluginName, data);	/* store with element */
      });
    },

    /**
     * Turn the pane into a tabbed pane
     */
    makeTabbed: function() {
      var children = this.children();
      var ul = $.el.ul({ class:"nav nav-tabs",
			 role:"tablist"
		       });
      var contents = $.el.div({class:"tab-content"});

      this.prepend(contents);
      this.prepend(ul);

      $(ul).on("click", "span.xclose", function(ev) {
	var id = $(ev.target).parent().attr("data-id");
	$(ev.target).parents(".tabbed").first().tabbed('removeTab', id);
	ev.preventDefault();
      });
      $(ul).on("click", "a", function(ev) {
	$(ev.target).tab('show');
	ev.preventDefault();
      });

      for(var i=0; i<children.length; i++) {
	var child = $(children[i]);
	var id = genId();
	var label = child.attr("data-label") || "Unknown";
	var close = child.attr("data-close") != "disabled";

	var li = this.tabbed('tabLabel', id, label, close);
	if ( i == 0 )
	  $(li).addClass("active");
	$(ul).append(li);
	$(contents).append(wrapInTab($(children[i]), id, i == 0));
      }

      var create = $.el.a({ class: "tab-new compact",
			    title: "Open a new tab"
			  },
			  glyphicon("plus"));
      $(ul).append($.el.li({ role:"presentation" }, create));
      $(create).on("click", function(ev) {
	var tabbed = $(ev.target).parents(".tabbed").first();

	var e = $("<div>Hello World</div>");
	tabbed.tabbed('addTab', e, {active:true,close:true});
	ev.preventDefault();
	return false;
      });
    },

    /**
     * Add a new tab using content
     * @param {Object} content is the DOM node to use as content for the
     * tab.
     * @param {Object} options
     * @param {Boolean} [options.active] if `true`, make the new tab
     * active
     * @param {Boolean} [options.close] if `true`, allow closing the new
     * tab.
     */
    addTab: function(content, options) {
      var ul = this.tabbed('navTabs');
      var id = genId();

      this.tabbed('navContent').append(wrapInTab(content, id, options.close));

      var li  = this.tabbed('tabLabel', id, "New tab", close);

      var create = ul.find("a.tab-new");
      if ( create.length == 1 )
	$(li).insertBefore(create.first().parent());
      else
	ul.append(li);

      if ( options.active )
	$(li).find("a").first().tab('show');
    },

    /**
     * Remove tab with given Id. If the tab is the active tab, make the
     * previous tab active, or if there is no previous, the next.
     *
     * @param {String} id is the id of the tab to destroy
     */
    removeTab: function(id) {
      var li = this.tabbed('navTabs').find("a[data-id='"+id+"']").parent();
      var new_active;

      if ( $("#"+id).is(":visible") )
	new_active = li.prev() || li.next();
      li.remove();
      $("#"+id).remove();
      if ( new_active )
	new_active.find("a").first().tab('show');
    },

    /**
     * Create a label (`li`) for a new tab.
     */
    tabLabel: function(id, name, close) {
      var close_button;

      if ( close )
      { close_button = glyphicon("remove", "xclose");
	$(close_button).attr("title", "Close tab");
      }

      var a1 = $.el.a({class:"compact", href:"#"+id, "data-id":id},
		      name, close_button);
      var li = $.el.li({role:"presentation"}, a1);

      return li;
    },

    /**
     * Get the UL list that represents the nav tabs
     */
    navTabs: function() {
      return this.find("ul.nav-tabs").first();
    },

    navContent: function() {
      return this.find("div.tab-content").first();
    }
  }; // methods

  /**
   * Wrap a content element in a Bootstrap tab content.
   * @param dom is the object that must be wrapped
   * @param id is the identifier to give to the new content
   * @param active sets the tab to active if `true`
   */
  function wrapInTab(dom, id, active) {
    dom.wrap('<div role="tabpanel" class="tab-pane" id="'+id+'"></div>');
    var wrapped = dom.parent();

    if ( active )
      wrapped.addClass("active");

    return wrapped;
  }

  function glyphicon(glyph, className) {
    var span = $.el.span({class:"glyphicon glyphicon-"+glyph});

    if ( className )
      $(span).addClass(className);

    return span;
  }

  function genId()
  { return "tabbed-tab-"+tabid++;
  }


  /**
   * <Class description>
   *
   * @class tabbed
   * @tutorial jquery-doc
   * @memberOf $.fn
   * @param {String|Object} [method] Either a method name or the jQuery
   * plugin initialization object.
   * @param [...] Zero or more arguments passed to the jQuery `method`
   */

  $.fn.tabbed = function(method) {
    if ( methods[method] ) {
      return methods[method]
	.apply(this, Array.prototype.slice.call(arguments, 1));
    } else if ( typeof method === 'object' || !method ) {
      return methods._init.apply(this, arguments);
    } else {
      $.error('Method ' + method + ' does not exist on jQuery.' + pluginName);
    }
  };
}(jQuery));
});
