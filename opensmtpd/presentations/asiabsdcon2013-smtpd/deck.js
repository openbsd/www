/*! This is a concatenation of several files. Check the various copyright notice */
/*!
Deck JS - deck.core
Copyright (c) 2011 Caleb Troughton
Dual licensed under the MIT license and GPL license.
https://github.com/imakewebthings/deck.js/blob/master/MIT-license.txt
https://github.com/imakewebthings/deck.js/blob/master/GPL-license.txt
*/

/*
The deck.core module provides all the basic functionality for creating and
moving through a deck.  It does so by applying classes to indicate the state of
the deck and its slides, allowing CSS to take care of the visual representation
of each state.  It also provides methods for navigating the deck and inspecting
its state, as well as basic key bindings for going to the next and previous
slides.  More functionality is provided by wholly separate extension modules
that use the API provided by core.
*/
(function($, deck, document, undefined) {
	var slides, // Array of all the uh, slides...
	current, // Array index of the current slide
	$container, // Keeping this cached
	
	events = {
		/*
		This event fires whenever the current slide changes, whether by way of
		next, prev, or go. The callback function is passed two parameters, from
		and to, equal to the indices of the old slide and the new slide
		respectively. If preventDefault is called on the event within this handler
		the slide change does not occur.
		
		$(document).bind('deck.change', function(event, from, to) {
		   alert('Moving from slide ' + from + ' to ' + to);
		});
		*/
		change: 'deck.change',
		
		/*
		This event fires at the beginning of deck initialization, after the options
		are set but before the slides array is created.  This event makes a good hook
		for preprocessing extensions looking to modify the deck.
		*/
		beforeInitialize: 'deck.beforeInit',
		
		/*
		This event fires at the end of deck initialization. Extensions should
		implement any code that relies on user extensible options (key bindings,
		element selectors, classes) within a handler for this event. Native
		events associated with Deck JS should be scoped under a .deck event
		namespace, as with the example below:
		
		var $d = $(document);
		$.deck.defaults.keys.myExtensionKeycode = 70; // 'h'
		$d.bind('deck.init', function() {
		   $d.bind('keydown.deck', function(event) {
		      if (event.which === $.deck.getOptions().keys.myExtensionKeycode) {
		         // Rock out
		      }
		   });
		});
		*/
		initialize: 'deck.init' 
	},
	
	options = {},
	$d = $(document),
	
	/*
	Internal function. Updates slide and container classes based on which
	slide is the current slide.
	*/
	updateStates = function() {
		var oc = options.classes,
		osc = options.selectors.container,
		old = $container.data('onSlide'),
		$all = $();
		
		// Container state
		$container.removeClass(oc.onPrefix + old)
			.addClass(oc.onPrefix + current)
			.data('onSlide', current);
		
		// Remove and re-add child-current classes for nesting
		$('.' + oc.current).parentsUntil(osc).removeClass(oc.childCurrent);
		slides[current].parentsUntil(osc).addClass(oc.childCurrent);
		
		// Remove previous states
		$.each(slides, function(i, el) {
			$all = $all.add(el);
		});
		$all.removeClass([
			oc.before,
			oc.previous,
			oc.current,
			oc.next,
			oc.after
		].join(" "));
		
		// Add new states back in
		slides[current].addClass(oc.current);
		if (current > 0) {
			slides[current-1].addClass(oc.previous);
		}
		if (current + 1 < slides.length) {
			slides[current+1].addClass(oc.next);
		}
		if (current > 1) {
			$.each(slides.slice(0, current - 1), function(i, el) {
				el.addClass(oc.before);
			});
		}
		if (current + 2 < slides.length) {
			$.each(slides.slice(current+2), function(i, el) {
				el.addClass(oc.after);
			});
		}
	},
	
	/* Methods exposed in the jQuery.deck namespace */
	methods = {
		
		/*
		jQuery.deck(selector, options)
		
		selector: string | jQuery | array
		options: object, optional
				
		Initializes the deck, using each element matched by selector as a slide.
		May also be passed an array of string selectors or jQuery objects, in
		which case each selector in the array is considered a slide. The second
		parameter is an optional options object which will extend the default
		values.
		
		$.deck('.slide');
		
		or
		
		$.deck([
		   '#first-slide',
		   '#second-slide',
		   '#etc'
		]);
		*/	
		init: function(elements, opts) {
			var startTouch,
			tolerance,
			esp = function(e) {
				e.stopPropagation();
			};
			
			options = $.extend(true, {}, $[deck].defaults, opts);
			slides = [];
			current = 0;
			$container = $(options.selectors.container);
			tolerance = options.touch.swipeTolerance;
			
			// Pre init event for preprocessing hooks
			$d.trigger(events.beforeInitialize);
			
			// Hide the deck while states are being applied to kill transitions
			$container.addClass(options.classes.loading);
			
			// Fill slides array depending on parameter type
			if ($.isArray(elements)) {
				$.each(elements, function(i, e) {
					slides.push($(e));
				});
			}
			else {
				$(elements).each(function(i, e) {
					slides.push($(e));
				});
			}
			
			/* Remove any previous bindings, and rebind key events */
			$d.unbind('keydown.deck').bind('keydown.deck', function(e) {
				if (e.which === options.keys.next || $.inArray(e.which, options.keys.next) > -1) {
					methods.next();
					e.preventDefault();
				}
				else if (e.which === options.keys.previous || $.inArray(e.which, options.keys.previous) > -1) {
					methods.prev();
					e.preventDefault();
				}
			})
			/* Stop propagation of key events within editable elements */
			.undelegate('input, textarea, select, button, meter, progress, [contentEditable]', 'keydown', esp)
			.delegate('input, textarea, select, button, meter, progress, [contentEditable]', 'keydown', esp);
			
			/* Bind touch events for swiping between slides on touch devices */
			$container.unbind('touchstart.deck').bind('touchstart.deck', function(e) {
				if (!startTouch) {
					startTouch = $.extend({}, e.originalEvent.targetTouches[0]);
				}
			})
			.unbind('touchmove.deck').bind('touchmove.deck', function(e) {
				$.each(e.originalEvent.changedTouches, function(i, t) {
					if (startTouch && t.identifier === startTouch.identifier) {
						if (t.screenX - startTouch.screenX > tolerance || t.screenY - startTouch.screenY > tolerance) {
							$[deck]('prev');
							startTouch = undefined;
						}
						else if (t.screenX - startTouch.screenX < -1 * tolerance || t.screenY - startTouch.screenY < -1 * tolerance) {
							$[deck]('next');
							startTouch = undefined;
						}
						return false;
					}
				});
				e.preventDefault();
			})
			.unbind('touchend.deck').bind('touchend.deck', function(t) {
				$.each(t.originalEvent.changedTouches, function(i, t) {
					if (startTouch && t.identifier === startTouch.identifier) {
						startTouch = undefined;
					}
				});
			})
			.scrollLeft(0).scrollTop(0);
			
			/*
			Kick iframe videos, which dont like to redraw w/ transforms.
			Remove this if Webkit ever fixes it.
			 */
			$.each(slides, function(i, $el) {
				$el.unbind('webkitTransitionEnd.deck').bind('webkitTransitionEnd.deck',
				function(event) {
					if ($el.hasClass($[deck]('getOptions').classes.current)) {
						var embeds = $(this).find('iframe').css('opacity', 0);
						window.setTimeout(function() {
							embeds.css('opacity', 1);
						}, 100);
					}
				});
			});
			
			if (slides.length) {
				updateStates();
			}
			
			// Show deck again now that slides are in place
			$container.removeClass(options.classes.loading);
			$d.trigger(events.initialize);
		},
		
		/*
		jQuery.deck('go', index)
		
		index: integer | string
		
		Moves to the slide at the specified index if index is a number. Index is
		0-based, so $.deck('go', 0); will move to the first slide. If index is a
		string this will move to the slide with the specified id. If index is out
		of bounds or doesn't match a slide id the call is ignored.
		*/
		go: function(index) {
			var e = $.Event(events.change),
			ndx;
			
			/* Number index, easy. */
			if (typeof index === 'number' && index >= 0 && index < slides.length) {
				ndx = index;
			}
			/* Id string index, search for it and set integer index */
			else if (typeof index === 'string') {
				$.each(slides, function(i, $slide) {
					if ($slide.attr('id') === index) {
						ndx = i;
						return false;
					}
				});
			};
			
			/* Out of bounds, id doesn't exist, illegal input, eject */
			if (typeof ndx === 'undefined') return;
			
			$d.trigger(e, [current, ndx]);
			if (e.isDefaultPrevented()) {
				/* Trigger the event again and undo the damage done by extensions. */
				$d.trigger(events.change, [ndx, current]);
			}
			else {
				current = ndx;
				updateStates();
			}
		},
		
		/*
		jQuery.deck('next')
		
		Moves to the next slide. If the last slide is already active, the call
		is ignored.
		*/
		next: function() {
			methods.go(current+1);
		},
		
		/*
		jQuery.deck('prev')
		
		Moves to the previous slide. If the first slide is already active, the
		call is ignored.
		*/
		prev: function() {
			methods.go(current-1);
		},
		
		/*
		jQuery.deck('getSlide', index)
		
		index: integer, optional
		
		Returns a jQuery object containing the slide at index. If index is not
		specified, the current slide is returned.
		*/
		getSlide: function(index) {
			var i = typeof index !== 'undefined' ? index : current;
			if (typeof i != 'number' || i < 0 || i >= slides.length) return null;
			return slides[i];
		},
		
		/*
		jQuery.deck('getSlides')
		
		Returns all slides as an array of jQuery objects.
		*/
		getSlides: function() {
			return slides;
		},
		
		/*
		jQuery.deck('getContainer')
		
		Returns a jQuery object containing the deck container as defined by the
		container option.
		*/
		getContainer: function() {
			return $container;
		},
		
		/*
		jQuery.deck('getOptions')
		
		Returns the options object for the deck, including any overrides that
		were defined at initialization.
		*/
		getOptions: function() {
			return options;
		},
		
		/*
		jQuery.deck('extend', name, method)
		
		name: string
		method: function
		
		Adds method to the deck namespace with the key of name. This doesn’t
		give access to any private member data — public methods must still be
		used within method — but lets extension authors piggyback on the deck
		namespace rather than pollute jQuery.
		
		$.deck('extend', 'alert', function(msg) {
		   alert(msg);
		});

		// Alerts 'boom'
		$.deck('alert', 'boom');
		*/
		extend: function(name, method) {
			methods[name] = method;
		}
	};
	
	/* jQuery extension */
	$[deck] = function(method, arg) {
		if (methods[method]) {
			return methods[method].apply(this, Array.prototype.slice.call(arguments, 1));
		}
		else {
			return methods.init(method, arg);
		}
	};
	
	/*
	The default settings object for a deck. All deck extensions should extend
	this object to add defaults for any of their options.
	
	options.classes.after
		This class is added to all slides that appear after the 'next' slide.
	
	options.classes.before
		This class is added to all slides that appear before the 'previous'
		slide.
		
	options.classes.childCurrent
		This class is added to all elements in the DOM tree between the
		'current' slide and the deck container. For standard slides, this is
		mostly seen and used for nested slides.
		
	options.classes.current
		This class is added to the current slide.
		
	options.classes.loading
		This class is applied to the deck container during loading phases and is
		primarily used as a way to short circuit transitions between states
		where such transitions are distracting or unwanted.  For example, this
		class is applied during deck initialization and then removed to prevent
		all the slides from appearing stacked and transitioning into place
		on load.
		
	options.classes.next
		This class is added to the slide immediately following the 'current'
		slide.
		
	options.classes.onPrefix
		This prefix, concatenated with the current slide index, is added to the
		deck container as you change slides.
		
	options.classes.previous
		This class is added to the slide immediately preceding the 'current'
		slide.
		
	options.selectors.container
		Elements matched by this CSS selector will be considered the deck
		container. The deck container is used to scope certain states of the
		deck, as with the onPrefix option, or with extensions such as deck.goto
		and deck.menu.
		
	options.keys.next
		The numeric keycode used to go to the next slide.
		
	options.keys.previous
		The numeric keycode used to go to the previous slide.
		
	options.touch.swipeTolerance
		The number of pixels the users finger must travel to produce a swipe
		gesture.
	*/
	$[deck].defaults = {
		classes: {
			after: 'deck-after',
			before: 'deck-before',
			childCurrent: 'deck-child-current',
			current: 'deck-current',
			loading: 'deck-loading',
			next: 'deck-next',
			onPrefix: 'on-slide-',
			previous: 'deck-previous'
		},
		
		selectors: {
			container: '.deck-container'
		},
		
		keys: {
			// enter, space, page down, right arrow, down arrow,
			next: [13, 32, 34, 39, 40],
			// backspace, page up, left arrow, up arrow
			previous: [8, 33, 37, 38]
		},
		
		touch: {
			swipeTolerance: 60
		}
	};
	
	$d.ready(function() {
		$('html').addClass('ready');
	});
	
	/*
	FF + Transforms + Flash video don't get along...
	Firefox will reload and start playing certain videos after a
	transform.  Blanking the src when a previously shown slide goes out
	of view prevents this.
	*/
	$d.bind('deck.change', function(e, from, to) {
		var oldFrames = $[deck]('getSlide', from).find('iframe'),
		newFrames = $[deck]('getSlide', to).find('iframe');
		
		oldFrames.each(function() {
	    	var $this = $(this),
	    	curSrc = $this.attr('src');
            
            if(curSrc) {
            	$this.data('deck-src', curSrc).attr('src', '');
            }
		});
		
		newFrames.each(function() {
			var $this = $(this),
			originalSrc = $this.data('deck-src');
			
			if (originalSrc) {
				$this.attr('src', originalSrc);
			}
		});
	});
})(jQuery, 'deck', document);
/*!
  Deck JS - deck.fit
  Copyright (c) 2012 Rémi Emonet
  Dual licensed under the MIT license and GPL license.
  https://github.com/imakewebthings/deck.js/blob/master/MIT-license.txt
  https://github.com/imakewebthings/deck.js/blob/master/GPL-license.txt
*/

/*
  This extension provides a way of scaling the slides to fit the slide container.
  A "design size" is used to do global scaling of all slides in the same way.
  The default design size is 800x600.
*/
(function($, deck, window, undefined) {
    var $d = $(document),
    $w = $(window),
    timer, // Timeout id for debouncing
    rootSlides,
    
    /*
      Internal function to do all the dirty work of scaling the slides.
    */
    scaleDeck = function() {
        var opts = $[deck]('getOptions');
        var addMarginX = opts.fitMarginX * 2;
        var addMarginY = opts.fitMarginY * 2;
        var fitMode = opts.fitMode;
        var sdw = opts.designWidth;
        var sdh = opts.designHeight;
        var $container = $[deck]('getContainer');
        var scaleX = $container.hasClass(opts.classes.globalscale) ? $container.innerWidth() / (sdw+addMarginX) : 1;
        var scaleY = $container.hasClass(opts.classes.globalscale) ? $container.innerHeight() / (sdh+addMarginY) : 1;
        var truescaleX = $container.hasClass(opts.classes.globalscale) ? $container.innerWidth() / (sdw) : 1;
        var truescaleY = $container.hasClass(opts.classes.globalscale) ? $container.innerHeight() / (sdh) : 1;
        var scale = scaleX < scaleY ? scaleX : scaleY;
        var rootSlides = [];
        var slideTest = $.map([opts.classes.before, opts.classes.previous, opts.classes.current, opts.classes.next, opts.classes.after],
                              function(el, i) {return '.' + el;}).join(', ');

        $.each($[deck]('getSlides'), function(i, $el) {
            if (!$el.parentsUntil(opts.selectors.container).length) {
                rootSlides.push($el);
            }
        });
        $.each(rootSlides, function(i, $slide) {
            $slide.width(sdw);
            $slide.height(sdh);
            $.each('Webkit Moz O ms Khtml'.split(' '), function(i, prefix) {
                if (scale == 1) {
                    $slide.css(prefix + 'Transform', '');
                } else {
                    if (fitMode == "left top" || fitMode == "top left") {
                        // ok align left/top (ok with the percents)
                        $slide.css(prefix + 'Transform', 'translate(-50%,-50%) scale(' + scale + ' , ' + scale + ') translate(50%,50%) translate('+(addMarginX/2)+'px,'+(addMarginY/2)+'px)');
                    } else if (fitMode == "center middle") {
                        // ok align center/middle
                        $slide.css(prefix + 'Transform', 'translate(-50%,-50%) scale(' + scale + ' , ' + scale + ') translate(50%, 50%) translate('+($container.innerWidth()/2/scale - sdw/2)+'px,'+($container.innerHeight()/2/scale - sdh/2)+'px)');
                    } else if (fitMode == "right bottom" || fitMode == "bottom right") {
                        // ok align right/bottom
                        $slide.css(prefix + 'Transform', 'translate(-50%,-50%) scale(' + scale + ' , ' + scale + ') translate(50%, 50%) translate('+($container.innerWidth()/scale - sdw - addMarginX/2)+'px,'+($container.innerHeight()/scale - sdh - addMarginY/2)+'px)');
                    } else if (fitMode == "stretched") {
                        // ok stretched (with respect of the margin, i.e., it is center/middle)
                        $slide.css(prefix + 'Transform', 'scale(' + scaleX + ' , ' + scaleY + ') translate('+(($container.innerWidth()-sdw)/2/scaleX)+'px,'+(($container.innerHeight()-sdh)/2/scaleY)+'px)');
                    }
                }
            });
        });
        
    }
    
    /*
      Extends defaults/options.
      
      options.designWidth
      Defaults to 800. You may instead specify a width as a number
      of px and all slides will be scaled in the same way, considering their
      size is the provided one.
      
      options.designHeight
      Defaults to 600. You may instead specify a height as a number
      of px and all slides will be scaled in the same way, considering their
      size is the provided one.
      
      options.fitMode
      How to adapt the slide to the container.
      Only the following combinations are available for now:
      "center middle", "top left", "bottom right", "stretched"
    
      options.fitMarginX
      options.fitMarginY
      Defaults to 5. Adds some margin in design space units.
      E.g., if the designe width is 800 and the margin is 5, the slide will be
      810 pixel wide before rescaling.
    
      options.scaleDebounce
      Scaling on the browser resize event is debounced. This number is the
      threshold in milliseconds. You can learn more about debouncing here:
      http://unscriptable.com/index.php/2009/03/20/debouncing-javascript-methods/
      
    */
    $.extend(true, $[deck].defaults, {
        classes: {
            globalscale: 'deck-globalscale'
        },
        keys: {
            scale: 83 // s
        },
        
        designWidth: 800,
        designHeight: 600,
        fitMode: "center middle",
        fitMarginX: 5,
        fitMarginY: 5,
        scaleDebounce: 200
    });
    
    /*
      jQuery.deck('disableScale')
      
      Disables scaling and removes the scale class from the deck container.
    */
    $[deck]('extend', 'disableScale', function() {
        $[deck]('getContainer').removeClass($[deck]('getOptions').classes.globalscale);
        scaleDeck();
    });
    
    /*
      jQuery.deck('enableScale')
      
      Enables scaling and adds the scale class to the deck container.
    */
    $[deck]('extend', 'enableScale', function() {
        $[deck]('getContainer').addClass($[deck]('getOptions').classes.globalscale);
        scaleDeck();
    });
    
    /*
      jQuery.deck('toggleScale')
      
      Toggles between enabling and disabling scaling.
    */
    $[deck]('extend', 'toggleScale', function() {
        var $c = $[deck]('getContainer');
        $[deck]($c.hasClass($[deck]('getOptions').classes.globalscale) ?
                'disableScale' : 'enableScale');
    });
    
    $d.bind('deck.init', function() {
        var opts = $[deck]('getOptions');
        
        // Debounce the resize scaling
        $w.unbind('resize.deckscale').bind('resize.deckscale', function() {
            window.clearTimeout(timer);
            timer = window.setTimeout(scaleDeck, opts.scaleDebounce);
        })
        // Scale once on load, in case images or something change layout
            .unbind('load.deckscale').bind('load.deckscale', scaleDeck);
        
        // Bind key events
        $d.unbind('keydown.deckscale').bind('keydown.deckscale', function(e) {
            if (e.which === opts.keys.scale || $.inArray(e.which, opts.keys.scale) > -1) {
                $[deck]('toggleScale');
                e.preventDefault();
            }
        });
        
        // Enable scale on init
        $[deck]('enableScale');
    });
})(jQuery, 'deck', this);

/*!
Deck JS - deck.smartsyntax
Copyright (c) 2012 Rémi Emonet
Dual licensed under the MIT license and GPL license.
https://github.com/imakewebthings/deck.js/blob/master/MIT-license.txt
https://github.com/imakewebthings/deck.js/blob/master/GPL-license.txt
*/

/*
This module provides a support for a shorter syntax for slides.
*/

(function($, deck, undefined) {
    var $d = $(document);
    var may = function(f) {return f ? f : function() {}};
    var startsWith = function(longStr, part) {return longStr.substr(0, part.length) == part;}
    var startsWithIgnoreCase = function(longStr, part) {return longStr.substr(0, part.length).toUpperCase() == part.toUpperCase();}
    var maybeAddClasses = function(toWhat, spaceSeparatedClasses, uniqueId) {
        if (uniqueId != "") $(toWhat).attr("id", uniqueId);
        if (spaceSeparatedClasses == "") return;
        var parts = spaceSeparatedClasses.split(/ +/);
        for (i in parts) {
            $(toWhat).addClass(parts[i]);
        }
    }

    var interpretationOfSmartLanguage = function(smart, doc) {
        var res = new Array();
        var inSlide = null;
        var indent = "";
        var deepestList = null;
        var remain = smart;

        var processMath = function(content) {
            return content.replace(/\$([^$][^$]*)\$/g, '<span class="latex">\\displaystyle $1</span>').replace(/\$\$/, '$');
        }
        
        var setEnrichedContent = function(what, content) {
            content = processMath(content);
            return what.innerHTML = content;
        }
        var endSlide = function() {
            inSlide = null;
            indent = new Array();
            indent = "";
            deepestList = null;
        }
        
        while (true) {
            var nl = remain.indexOf("\n");
            var line = remain.substring(0, nl).replace(/^ */, "");
            // we iterate over the lines
            // treat trailing unique-id and classes before anything
            var uniqueId = "";
            while (line.match(/^(.*)#([^\]\| >]*)$/)) {
                uniqueId = RegExp.$2;
                line = RegExp.$1;
            }
            var addClasses = "";
            {
                while (line.match(/^(.*)\[([^\] >]*)\]$/)) {
                    addClasses = RegExp.$2 + " " + addClasses;
                    line = RegExp.$1;
                }
            }
            if (line == "") {
            } else if (line.match(/^==(.*)==$/)) {
                var title = RegExp.$1;
                if (inSlide) endSlide();
                inSlide = doc.createElement("section");
                $(inSlide).addClass("slide");
                maybeAddClasses(inSlide, addClasses, uniqueId);
                var h = doc.createElement("h1");
                setEnrichedContent(h, title);
                inSlide.appendChild(h);
                deepestList = inSlide;
                res[res.length] = inSlide;
            } else if (line.match(/^=(.*)=$/)) {
                var title = RegExp.$1;
                if (inSlide) endSlide();
                inSlide = doc.createElement("section");
                $(inSlide).addClass("slide");
                maybeAddClasses(inSlide, addClasses, uniqueId);
                var h = doc.createElement("h2");
                setEnrichedContent(h, title);
                inSlide.appendChild(h);
                deepestList = inSlide;
                res[res.length] = inSlide;
            } else if (line.match(/^([-*#]+)(.*)$/)) {
                var pref = RegExp.$1;
                var content = RegExp.$2;
                if (indent == "" && pref == "") {
                    // do not create the li
                } else if (pref == indent) {
                    var li = doc.createElement("li");
                    maybeAddClasses(li, addClasses, uniqueId);
                    setEnrichedContent(li, content);
                    deepestList.appendChild(li);
                } else {
                    // un-push as needed
                    while (! startsWith(pref, indent)) {
                        deepestList = deepestList.parentNode;
                        if (deepestList.tagName == "LI") deepestList = deepestList.parentNode;
                        indent = indent.substr(0, indent.length - 1);
                    }
                    // clean the special '-' that we can use for magic unpush
                    pref = pref.replace(/^-*/, "");
                    // re-push as needed
                    while (pref.length > indent.length) {
                        var asso = {"*": "ul", "#": "ol"};
                        var toPush = pref.substr(indent.length, 1);
                        indent = indent.concat(toPush);
                        var list = doc.createElement(asso[toPush]);
                        if ((deepestList.tagName == "UL" || deepestList.tagName == "OL") && deepestList.childNodes.length > 0) {
                            deepestList.lastChild.appendChild(list);
                        } else {
                            deepestList.appendChild(list);
                        }
                        deepestList = list;
                    }
                    if (indent == "" && pref == "") {
                        // do not create the li
                    } else {
                        var li = doc.createElement("li");
                        maybeAddClasses(li, addClasses, uniqueId);
                        setEnrichedContent(li, content);
                        deepestList.appendChild(li);
                    }
                }
            } else if (startsWithIgnoreCase(line, "@SVG:")) {
                var parts = line.replace(/@SVG\: */i, "").split(/ +/);
                var obj = $("<object type='deckjs/svg'/>");
                $.each(parts[0].split(/,/), function(i,c){obj.addClass(c);});
                obj.append($("<param name='src'/>").attr("value", parts[1]))
                    .append($("<param name='width'/>").attr("value", parts[2]))
                    .append($("<param name='height'/>").attr("value", parts[3]))
                    .appendTo(inSlide);
            } else if (startsWithIgnoreCase(line, "@ANIM-PLAY:")) {
                line = line.replace(/@ANIM-PLAY\: */i, "");
                $("<div/>").addClass("anim-play slide").attr("data-what", line).appendTo(deepestList);
            } else if (startsWithIgnoreCase(line, "@ANIM-PAUSE:")) {
                line = line.replace(/@ANIM-PAUSE\: */i, "");
                $("<div/>").addClass("anim-pause slide").attr("data-what", line).appendTo(deepestList);
            } else if (startsWithIgnoreCase(line, "@ANIM-ATTRIBUTE:")) {
                line = line.replace(/@ANIM-ATTRIBUTE\: */i, "");
                var main = line.split(/ *: */);
                $("<div/>").addClass("anim-attribute slide").attr("data-dur", main[0]).attr("data-what", main[1]).attr("data-attr", main[2]+":"+main[3]).appendTo(deepestList);
            } else if (startsWithIgnoreCase(line, "@ANIM-APPEAR:")) {
                line = line.replace(/@ANIM-APPEAR\: */i, "");
                if (uniqueId != "") line += "#"+uniqueId; // restore possibly removed id
                var main = line.split(/ *: */);
                var dur = main[0];
                var parts = main[1].split(/ *\| */);
                for (i in parts) {
                    // process each group of simultaneous animations
                    var subparts = parts[i].split(/ *\+ */);
                    for (ii in subparts) {
                        var what = subparts[ii];
                        var continuating  = ii != subparts.length-1;
                        var add = $("<div/>");
                        add.attr("data-dur", dur);
                        if (what[0] == '-') {
                            add.addClass("anim-hide");
                            what = what.substring(1);
                        } else if (what[0] == '@') {
                            // TODO if it looks like @....@ then the target is specified, else it is just all SVGs root elements
                            add.addClass("anim-viewboxas");
                            what = what.substring(1);
                            add.attr("data-as", what);
                            what = "svg";
                        } else {
                            add.addClass("anim-show");
                        }
                        add.addClass("slide").attr("data-what", what);
                        if (continuating) add.addClass("anim-continue");
                        add.appendTo(deepestList);
                    }
                }
            } else if (startsWith(line, "@<")) {
                line = line.replace(/^@/, "");
                var contentToAdd = "";
                // test on remain to avoid infinite loop
                while (line != null && remain.length != 0) {
                    if (line.match(/^@<\//)) {
                        // normal stopping condition
                        line = line.replace(/^@/, "");
                        contentToAdd += "  " + line + "\n";
                        break;
                    }
                    if (nl != -1) remain = remain.substring(nl + 1);
                    contentToAdd += "  " + line + "\n";
                    nl = remain.indexOf("\n");
                    line = remain.substring(0, nl).replace(/^ */, "");
                }
                deepestList.innerHTML = deepestList.innerHTML + processMath(contentToAdd) + " ";
            } else {
                while (true) {
                    try {
                        deepestList.innerHTML = deepestList.innerHTML + processMath(line) + " ";
                        break;
                    } catch (e) {
                        // TODO was ok with xhtml not really now
                        remain = remain.substring(nl + 1);
                        nl = remain.indexOf("\n");
                        var line2 = remain.substring(0, nl).replace(/^ */, "");
                        line = line + "\n" + line2;
                    }
                }
            }
            if (nl != -1) remain = remain.substring(nl + 1);
            else break;
        }
        return res;
    }

    // this have to be executed before the deck init
    $d.bind('deck.beforeInit', function() {
            $('.smart').each(function() {
                    var it = this;
                    var slides = interpretationOfSmartLanguage(it.innerHTML, document);
                    it.innerHTML = ""; // clear the smart node
                    $(it).after(slides);
                });
        });

})(jQuery, 'deck');
/*!
Deck JS - deck.goto
Copyright (c) 2011 Caleb Troughton
Dual licensed under the MIT license and GPL license.
https://github.com/imakewebthings/deck.js/blob/master/MIT-license.txt
https://github.com/imakewebthings/deck.js/blob/master/GPL-license.txt
*/

/*
This module adds the necessary methods and key bindings to show and hide a form
for jumping to any slide number/id in the deck (and processes that form
accordingly). The form-showing state is indicated by the presence of a class on
the deck container.
*/
(function($, deck, undefined) {
	var $d = $(document);
	
	/*
	Extends defaults/options.
	
	options.classes.goto
		This class is added to the deck container when showing the Go To Slide
		form.
		
	options.selectors.gotoDatalist
		The element that matches this selector is the datalist element that will
		be populated with options for each of the slide ids.  In browsers that
		support the datalist element, this provides a drop list of slide ids to
		aid the user in selecting a slide.
		
	options.selectors.gotoForm
		The element that matches this selector is the form that is submitted
		when a user hits enter after typing a slide number/id in the gotoInput
		element.
	
	options.selectors.gotoInput
		The element that matches this selector is the text input field for
		entering a slide number/id in the Go To Slide form.
		
	options.keys.goto
		The numeric keycode used to show the Go To Slide form.
		
	options.countNested
		If false, only top level slides will be counted when entering a
		slide number.
	*/
	$.extend(true, $[deck].defaults, {
		classes: {
			goto: 'deck-goto'
		},
		
		selectors: {
			gotoDatalist: '#goto-datalist',
			gotoForm: '.goto-form',
			gotoInput: '#goto-slide'
		},
		
		keys: {
			goto: 71 // g
		},
		
		countNested: true
	});

	/*
	jQuery.deck('showGoTo')
	
	Shows the Go To Slide form by adding the class specified by the goto class
	option to the deck container.
	*/
	$[deck]('extend', 'showGoTo', function() {
		$[deck]('getContainer').addClass($[deck]('getOptions').classes.goto);
		$($[deck]('getOptions').selectors.gotoInput).focus();
	});

	/*
	jQuery.deck('hideGoTo')
	
	Hides the Go To Slide form by removing the class specified by the goto class
	option from the deck container.
	*/
	$[deck]('extend', 'hideGoTo', function() {
		$($[deck]('getOptions').selectors.gotoInput).blur();
		$[deck]('getContainer').removeClass($[deck]('getOptions').classes.goto);
	});

	/*
	jQuery.deck('toggleGoTo')
	
	Toggles between showing and hiding the Go To Slide form.
	*/
	$[deck]('extend', 'toggleGoTo', function() {
		$[deck]($[deck]('getContainer').hasClass($[deck]('getOptions').classes.goto) ? 'hideGoTo' : 'showGoTo');
	});
	
	$d.bind('deck.init', function() {
		var opts = $[deck]('getOptions'),
		$datalist = $(opts.selectors.gotoDatalist),
		slideTest = $.map([
			opts.classes.before,
			opts.classes.previous,
			opts.classes.current,
			opts.classes.next,
			opts.classes.after
		], function(el, i) {
			return '.' + el;
		}).join(', '),
		rootCounter = 1;
		
		// Bind key events
		$d.unbind('keydown.deckgoto').bind('keydown.deckgoto', function(e) {
			var key = $[deck]('getOptions').keys.goto;
			
			if (e.which === key || $.inArray(e.which, key) > -1) {
				e.preventDefault();
				$[deck]('toggleGoTo');
			}
		});
		
		/* Populate datalist and work out countNested*/
		$.each($[deck]('getSlides'), function(i, $slide) {
			var id = $slide.attr('id'),
			$parentSlides = $slide.parentsUntil(opts.selectors.container, slideTest);
			
			if (id) {
				$datalist.append('<option value="' + id + '">');
			}
			
			if ($parentSlides.length) {
				$slide.removeData('rootIndex');
			}
			else if (!opts.countNested) {
				$slide.data('rootIndex', rootCounter);
				++rootCounter;
			}
		});
		
		// Process form submittal, go to the slide entered
		$(opts.selectors.gotoForm)
		.unbind('submit.deckgoto')
		.bind('submit.deckgoto', function(e) {
			var $field = $($[deck]('getOptions').selectors.gotoInput),
			ndx = parseInt($field.val(), 10);
			
			if (!$[deck]('getOptions').countNested) {
			  if (ndx >= rootCounter) return false;
				$.each($[deck]('getSlides'), function(i, $slide) {
					if ($slide.data('rootIndex') === ndx) {
						ndx = i + 1;
						return false;
					}
				});
			}
			
			$[deck]('go', isNaN(ndx) ? $field.val() : ndx - 1);
			$[deck]('hideGoTo');
			$field.val('');
			
			e.preventDefault();
		});
		
		// Dont let keys in the input trigger deck actions
		$(opts.selectors.gotoInput)
		.unbind('keydown.deckgoto')
		.bind('keydown.deckgoto', function(e) {
			e.stopPropagation();
		});
	});
})(jQuery, 'deck');

/*!
Deck JS - deck.status
Copyright (c) 2011 Caleb Troughton
Dual licensed under the MIT license and GPL license.
https://github.com/imakewebthings/deck.js/blob/master/MIT-license.txt
https://github.com/imakewebthings/deck.js/blob/master/GPL-license.txt
*/

/*
This module adds a (current)/(total) style status indicator to the deck.
*/
(function($, deck, undefined) {
	var $d = $(document),
	
	updateCurrent = function(e, from, to) {
		var opts = $[deck]('getOptions');
		
		$(opts.selectors.statusCurrent).text(opts.countNested ?
			to + 1 :
			$[deck]('getSlide', to).data('rootSlide')
		);
	};
	
	/*
	Extends defaults/options.
	
	options.selectors.statusCurrent
		The element matching this selector displays the current slide number.
		
	options.selectors.statusTotal
		The element matching this selector displays the total number of slides.
		
	options.countNested
		If false, only top level slides will be counted in the current and
		total numbers.
	*/
	$.extend(true, $[deck].defaults, {
		selectors: {
			statusCurrent: '.deck-status-current',
			statusTotal: '.deck-status-total',
			statusFakeEnd: '.deck-status-fake-end',
			statusFullTotal: '.deck-status-full-total'
		},
		
		countNested: true
	});
	
	$d.bind('deck.init', function() {
		var opts = $[deck]('getOptions'),
		slides = $[deck]('getSlides'),
		$current = $[deck]('getSlide'),
		ndx;
		
		// Set total slides once
		if (opts.countNested) {
			var notfound = 1000000;
			var fakeEnd = notfound;
			$.each(slides, function(i, $el) {
				if (fakeEnd > i) {
					if ($el.filter(opts.selectors.statusFakeEnd).length) {
						fakeEnd = i;
					}
				}
			});
			$(opts.selectors.statusTotal).text(fakeEnd == notfound ? slides.length : fakeEnd+1);
			$(opts.selectors.statusFullTotal).text(slides.length);
		}
		else {
			/* Determine root slides by checking each slide's ancestor tree for
			any of the slide classes. */
			var rootIndex = 1,
			slideTest = $.map([
				opts.classes.before,
				opts.classes.previous,
				opts.classes.current,
				opts.classes.next,
				opts.classes.after
			], function(el, i) {
				return '.' + el;
			}).join(', ');
			
			/* Store the 'real' root slide number for use during slide changes. */
			$.each(slides, function(i, $el) {
				var $parentSlides = $el.parentsUntil(opts.selectors.container, slideTest);

				$el.data('rootSlide', $parentSlides.length ?
					$parentSlides.last().data('rootSlide') :
					rootIndex++
				);
			});

			var notfound = 1000000;
			var fakeEnd = notfound;
			var rootOfFakeEnd = null;
			$.each(slides, function(i, $el) {
				if (fakeEnd > i) {
					if ($el.filter(opts.selectors.statusFakeEnd).length) {
						fakeEnd = i;
						rootOfFakeEnd = $el.data('rootSlide');
					}
				}
			});

			$(opts.selectors.statusTotal).text(fakeEnd == notfound ? rootIndex - 1 : rootOfFakeEnd);
			$(opts.selectors.statusFullTotal).text(rootIndex - 1);
		}
		
		// Find where we started in the deck and set initial state
		$.each(slides, function(i, $el) {
			if ($el === $current) {
				ndx = i;
				return false;
			}
		});
		updateCurrent(null, ndx, ndx);
	})
	/* Update current slide number with each change event */
	.bind('deck.change', updateCurrent);
})(jQuery, 'deck');

/*!
Deck JS - deck.menu
Copyright (c) 2011 Caleb Troughton
Dual licensed under the MIT license and GPL license.
https://github.com/imakewebthings/deck.js/blob/master/MIT-license.txt
https://github.com/imakewebthings/deck.js/blob/master/GPL-license.txt
*/

/*
This module adds the methods and key binding to show and hide a menu of all
slides in the deck. The deck menu state is indicated by the presence of a class
on the deck container.
*/
(function($, deck, undefined) {
	var $d = $(document),
	rootSlides; // Array of top level slides
	
	/*
	Extends defaults/options.
	
	options.classes.menu
		This class is added to the deck container when showing the slide menu.
	
	options.keys.menu
		The numeric keycode used to toggle between showing and hiding the slide
		menu.
		
	options.touch.doubletapWindow
		Two consecutive touch events within this number of milliseconds will
		be considered a double tap, and will toggle the menu on touch devices.
	*/
	$.extend(true, $[deck].defaults, {
		classes: {
			menu: 'deck-menu'
		},
		
		keys: {
			menu: 77 // m
		},
		
		touch: {
			doubletapWindow: 400
		}
	});

	/*
	jQuery.deck('showMenu')
	
	Shows the slide menu by adding the class specified by the menu class option
	to the deck container.
	*/
	$[deck]('extend', 'showMenu', function() {
		var $c = $[deck]('getContainer'),
		opts = $[deck]('getOptions');
		
		if ($c.hasClass(opts.classes.menu)) return;
		
		// Hide through loading class to short-circuit transitions (perf)
		$c.addClass([opts.classes.loading, opts.classes.menu].join(' '));
		
		/* Forced to do this in JS until CSS learns second-grade math. Save old
		style value for restoration when menu is hidden. */
		if (Modernizr.csstransforms) {
			$.each(rootSlides, function(i, $slide) {
				$slide.data('oldStyle', $slide.attr('style'));
				$slide.css({
					'position': 'absolute',
					'left': ((i % 4) * 25) + '%',
					'top': (Math.floor(i / 4) * 25) + '%'
				});
			});
		}
		
		// Need to ensure the loading class renders first, then remove
		window.setTimeout(function() {
			$c.removeClass(opts.classes.loading)
				.scrollTop($[deck]('getSlide').offset().top);
		}, 0);
	});

	/*
	jQuery.deck('hideMenu')
	
	Hides the slide menu by removing the class specified by the menu class
	option from the deck container.
	*/
	$[deck]('extend', 'hideMenu', function() {
		var $c = $[deck]('getContainer'),
		opts = $[deck]('getOptions');
		
		if (!$c.hasClass(opts.classes.menu)) return;
		
		$c.removeClass(opts.classes.menu);
		$c.addClass(opts.classes.loading);
		
		/* Restore old style value */
		if (Modernizr.csstransforms) {
			$.each(rootSlides, function(i, $slide) {
				var oldStyle = $slide.data('oldStyle');

				$slide.attr('style', oldStyle ? oldStyle : '');
			});
		}
		
		window.setTimeout(function() {
			$c.removeClass(opts.classes.loading).scrollTop(0);
		}, 0);
	});

	/*
	jQuery.deck('toggleMenu')
	
	Toggles between showing and hiding the slide menu.
	*/
	$[deck]('extend', 'toggleMenu', function() {
		$[deck]('getContainer').hasClass($[deck]('getOptions').classes.menu) ?
		$[deck]('hideMenu') : $[deck]('showMenu');
	});

	$d.bind('deck.init', function() {
		var opts = $[deck]('getOptions'),
		touchEndTime = 0,
		currentSlide,
		slideTest = $.map([
			opts.classes.before,
			opts.classes.previous,
			opts.classes.current,
			opts.classes.next,
			opts.classes.after
		], function(el, i) {
			return '.' + el;
		}).join(', ');
		
		// Build top level slides array
		rootSlides = [];
		$.each($[deck]('getSlides'), function(i, $el) {
			if (!$el.parentsUntil(opts.selectors.container, slideTest).length) {
				rootSlides.push($el);
			}
		});
		
		// Bind key events
		$d.unbind('keydown.deckmenu').bind('keydown.deckmenu', function(e) {
			if (e.which === opts.keys.menu || $.inArray(e.which, opts.keys.menu) > -1) {
				$[deck]('toggleMenu');
				e.preventDefault();
			}
		});
		
		// Double tap to toggle slide menu for touch devices
		$[deck]('getContainer').unbind('touchstart.deckmenu').bind('touchstart.deckmenu', function(e) {
			currentSlide = $[deck]('getSlide');
		})
		.unbind('touchend.deckmenu').bind('touchend.deckmenu', function(e) {
			var now = Date.now();
			
			// Ignore this touch event if it caused a nav change (swipe)
			if (currentSlide !== $[deck]('getSlide')) return;
			
			if (now - touchEndTime < opts.touch.doubletapWindow) {
				$[deck]('toggleMenu');
				e.preventDefault();
			}
			touchEndTime = now;
		});
		
		// Selecting slides from the menu
		$.each($[deck]('getSlides'), function(i, $s) {
			$s.unbind('click.deckmenu').bind('click.deckmenu', function(e) {
				if (!$[deck]('getContainer').hasClass(opts.classes.menu)) return;

				$[deck]('go', i);
				$[deck]('hideMenu');
				e.stopPropagation();
				e.preventDefault();
			});
		});
	})
	.bind('deck.change', function(e, from, to) {
		var container = $[deck]('getContainer');
		
		if (container.hasClass($[deck]('getOptions').classes.menu)) {
			container.scrollTop($[deck]('getSlide', to).offset().top);
		}
	});
})(jQuery, 'deck');

/*!
Deck JS - deck.hash
Copyright (c) 2011 Caleb Troughton
Dual licensed under the MIT license and GPL license.
https://github.com/imakewebthings/deck.js/blob/master/MIT-license.txt
https://github.com/imakewebthings/deck.js/blob/master/GPL-license.txt
*/

/*
This module adds deep linking to individual slides, enables internal links
to slides within decks, and updates the address bar with the hash as the user
moves through the deck. A permalink anchor is also updated. Standard themes
hide this link in browsers that support the History API, and show it for
those that do not. Slides that do not have an id are assigned one according to
the hashPrefix option. In addition to the on-slide container state class
kept by core, this module adds an on-slide state class that uses the id of each
slide.
*/
(function ($, deck, window, undefined) {
	var $d = $(document),
	$window = $(window),
	
	/* Collection of internal fragment links in the deck */
	$internals,
	
	/*
	Internal only function.  Given a string, extracts the id from the hash,
	matches it to the appropriate slide, and navigates there.
	*/
	goByHash = function(str) {
		var id = str.substr(str.indexOf("#") + 1),
		slides = $[deck]('getSlides');
		
		$.each(slides, function(i, $el) {
			if ($el.attr('id') === id) {
				$[deck]('go', i);
				return false;
			}
		});
		
		// If we don't set these to 0 the container scrolls due to hashchange
		$[deck]('getContainer').scrollLeft(0).scrollTop(0);
	};
	
	/*
	Extends defaults/options.
	
	options.selectors.hashLink
		The element matching this selector has its href attribute updated to
		the hash of the current slide as the user navigates through the deck.
		
	options.hashPrefix
		Every slide that does not have an id is assigned one at initialization.
		Assigned ids take the form of hashPrefix + slideIndex, e.g., slide-0,
		slide-12, etc.

	options.preventFragmentScroll
		When deep linking to a hash of a nested slide, this scrolls the deck
		container to the top, undoing the natural browser behavior of scrolling
		to the document fragment on load.
	*/
	$.extend(true, $[deck].defaults, {
		selectors: {
			hashLink: '.deck-permalink'
		},
		
		hashPrefix: 'slide-',
		preventFragmentScroll: true
	});
	
	
	$d.bind('deck.init', function() {
	   var opts = $[deck]('getOptions');
		$internals = $(),
		slides = $[deck]('getSlides');
		
		$.each(slides, function(i, $el) {
			var hash;
			
			/* Hand out ids to the unfortunate slides born without them */
			if (!$el.attr('id') || $el.data('deckAssignedId') === $el.attr('id')) {
				$el.attr('id', opts.hashPrefix + i);
				$el.data('deckAssignedId', opts.hashPrefix + i);
			}
			
			hash ='#' + $el.attr('id');
			
			/* Deep link to slides on init */
			if (hash === window.location.hash) {
				setTimeout(function() {$[deck]('go', i)}, 1);
			}
			
			/* Add internal links to this slide */
			$internals = $internals.add('a[href="' + hash + '"]');
		});
		
		if (!Modernizr.hashchange) {
			/* Set up internal links using click for the poor browsers
			without a hashchange event. */
			$internals.unbind('click.deckhash').bind('click.deckhash', function(e) {
				goByHash($(this).attr('href'));
			});
		}
		
		/* Set up first id container state class */
		if (slides.length) {
			$[deck]('getContainer').addClass(opts.classes.onPrefix + $[deck]('getSlide').attr('id'));
		};
	})
	/* Update permalink, address bar, and state class on a slide change */
	.bind('deck.change', function(e, from, to) {
		var hash = '#' + $[deck]('getSlide', to).attr('id'),
		hashPath = window.location.href.replace(/#.*/, '') + hash,
		opts = $[deck]('getOptions'),
		osp = opts.classes.onPrefix,
		$c = $[deck]('getContainer');
		
		$c.removeClass(osp + $[deck]('getSlide', from).attr('id'));
		$c.addClass(osp + $[deck]('getSlide', to).attr('id'));
		
		$(opts.selectors.hashLink).attr('href', hashPath);
		if (Modernizr.history) {
			window.history.replaceState({}, "", hashPath);
		}
	});
	
	/* Deals with internal links in modern browsers */
	$window.bind('hashchange.deckhash', function(e) {
		if (e.originalEvent && e.originalEvent.newURL) {
			goByHash(e.originalEvent.newURL);
		}
		else {
			goByHash(window.location.hash);
		}
	})
	/* Prevent scrolling on deep links */
	.bind('load', function() {
		if ($[deck]('getOptions').preventFragmentScroll) {
			$[deck]('getContainer').scrollLeft(0).scrollTop(0);
		}
	});
})(jQuery, 'deck', this);
/*!
Deck JS - deck.step
Copyright (c) 2011 Rémi Emonet
Dual licensed under the MIT license and GPL license.
https://github.com/imakewebthings/deck.js/blob/master/MIT-license.txt
https://github.com/imakewebthings/deck.js/blob/master/GPL-license.txt
*/

/*
This module provides new methods for stepping without considering sub-slides, together with tools for finding toplevel slides etc.
It also overrides the defaults keybinding and countNested value (so it is better to include it after "goto" and "status" extensions).
*/

(function($, deck, undefined) {
    var $d = $(document);
    // undo the defaults (to be sure jquery behaves properly when overriding it)
    $.extend(true, $[deck].defaults, { keys: {next:null, previous:null}});
    // and go on
    $.extend(true, $[deck].defaults, {
        selectors: {
            subslidesToNotify: ".slide,.onshowtoplevel"
        },
        // Here we redefined the defaults:
        //  - we avoid counting nested slides
        //  - we keep up/down for top-level slides
        //  - we still use pgup/pgdown for inner slides as they are sent by some pluggable remote controls
        keys: {
            // backspace, left arrow, page down
            previous: [8, 37, 34],
            // enter, space, right arrow, page up
            next: [13, 32, 39, 33],
            // up arrow
            previousTopLevel: [38],
            // down arrow,
            nextTopLevel: [40]
        },
        countNested: false
    });
    var myInArray = function(el, arr) {
        for (i in arr) if (arr[i].is(el)) return i*1; // cast to int
        return -1;
    };
    $[deck]('extend', 'getToplevelSlideOf', function(node) {
        var opts = $[deck]('getOptions');
        var slides = $[deck]('getSlides');
        var last = {node: $(node), index: myInArray(node, slides)};
        $(node).parentsUntil(opts.selectors.container).each( function(ii, v) {
            var ind = myInArray(v, slides);
            if (ind != -1) {
                last = {node: $(v), index: ind};
            }
        });
        return last;
    });
    $[deck]('extend', 'getToplevelSlideOfIndex', function(ind) {
        return $[deck]('getToplevelSlideOf', $[deck]('getSlide', ind));
    });
    $[deck]('extend', 'previousTopLevelSlide', function() {
        /* Find the real previous parent */
        var current = $[deck]('getSlide');
        var currentParent = $[deck]('getToplevelSlideOf', current);
        var toGo = currentParent.index;
        if (current.is(currentParent.node) && toGo > 0) {
            // This is already toplevel slide, just go to the previous toplevel one (parent of the previous one)
            toGo = $[deck]('getToplevelSlideOfIndex', toGo-1).index;
        }
        $[deck]('go', toGo);
        
    });
    $[deck]('extend', 'nextTopLevelSlide', function() {
        /* Find the real next parent */
        var current = $[deck]('getSlide');
        var currentParent = $[deck]('getToplevelSlideOf', current);
        var icur = currentParent.index;
        for (; icur < $[deck]('getSlides').length; icur++) {
            var cursorParent = $[deck]('getToplevelSlideOfIndex', icur).node;
            if (!cursorParent.is(currentParent.node)) {
                $[deck]('go', icur);
                break;
            }
        }
    });
    $d.bind('deck.init', function() {
        $d.unbind('keydown.decknexttoplevel').bind('keydown.decknexttoplevel', function(e) {
            var $opts = $[deck]('getOptions');
            var key = $opts.keys.nextTopLevel;
            if (e.which === key || $.inArray(e.which, key) > -1) {
                e.preventDefault();
                $[deck]('nextTopLevelSlide');
            }
        });
        $d.unbind('keydown.deckprevioustoplevel').bind('keydown.deckprevioustoplevel', function(e) {
            var $opts = $[deck]('getOptions');
            var key = $opts.keys.previousTopLevel;
            if (e.which === key || $.inArray(e.which, key) > -1) {
                e.preventDefault();
                $[deck]('previousTopLevelSlide');
            }
        });
    });
    // When jumping (not steping), we will init the subslides (in case they are animations), in a backward order, and then fast forward necessary animations
    var bigJump = function(from, to) {
        var direction = "forward";
        if (from > to){
            direction = "reverse";
        }
        var opts = $[deck]('getOptions');
        $($[deck]('getToplevelSlideOfIndex', to).node.find(opts.selectors.subslidesToNotify).get().reverse()).trigger('deck.toplevelBecameCurrent', direction);
        for (icur = $[deck]('getToplevelSlideOfIndex', to).index + 1; icur < to+1; icur++) {
            $[deck]('getSlides')[icur].trigger('deck.afterToplevelBecameCurrent', 'forward');
        }
    }
    $d.bind('deck.change', function(e, from, to) {
        if (  Math.abs(from - to) > 1 || ! $[deck]('getToplevelSlideOfIndex', to).node.is($[deck]('getToplevelSlideOfIndex', from).node)) {
            // consider natural jumps and the case where we actually changed (top level) slide (even with a step)
            bigJump(from, to);
        }
    });
})(jQuery, 'deck');
(function($, deck, undefined) {
   $(document).bind('deck.change', function(e, from, to) {
      var $prev = $[deck]('getSlide', to-1),
      $next = $[deck]('getSlide', to+1),
      $oldprev = $[deck]('getSlide', from-1),
      $oldnext = $[deck]('getSlide', from+1);
      
      var direction = "forward";
      if(from > to){
        direction = "reverse";
      }

      $[deck]('getSlide', to).trigger('deck.becameCurrent', [direction, from, to]);
      $[deck]('getSlide', from).trigger('deck.lostCurrent', [direction, from, to]);

      $prev && $prev.trigger('deck.becamePrevious', [direction, from, to]);
      $next && $next.trigger('deck.becameNext', [direction, from, to]);

      $oldprev && $oldprev.trigger('deck.lostPrevious', [direction, from, to]);
      $oldnext && $oldnext.trigger('deck.lostNext', [direction, from, to]);
   });
})(jQuery, 'deck');


(function($, deck, undefined) {
    // This next line is the color plugin from jquery
    (function(d){d.each(["backgroundColor","borderBottomColor","borderLeftColor","borderRightColor","borderTopColor","color","outlineColor"],function(f,e){d.fx.step[e]=function(g){if(!g.colorInit){g.start=c(g.elem,e);g.end=b(g.end);g.colorInit=true}g.elem.style[e]="rgb("+[Math.max(Math.min(parseInt((g.pos*(g.end[0]-g.start[0]))+g.start[0]),255),0),Math.max(Math.min(parseInt((g.pos*(g.end[1]-g.start[1]))+g.start[1]),255),0),Math.max(Math.min(parseInt((g.pos*(g.end[2]-g.start[2]))+g.start[2]),255),0)].join(",")+")"}});function b(f){var e;if(f&&f.constructor==Array&&f.length==3){return f}if(e=/rgb\(\s*([0-9]{1,3})\s*,\s*([0-9]{1,3})\s*,\s*([0-9]{1,3})\s*\)/.exec(f)){return[parseInt(e[1]),parseInt(e[2]),parseInt(e[3])]}if(e=/rgb\(\s*([0-9]+(?:\.[0-9]+)?)\%\s*,\s*([0-9]+(?:\.[0-9]+)?)\%\s*,\s*([0-9]+(?:\.[0-9]+)?)\%\s*\)/.exec(f)){return[parseFloat(e[1])*2.55,parseFloat(e[2])*2.55,parseFloat(e[3])*2.55]}if(e=/#([a-fA-F0-9]{2})([a-fA-F0-9]{2})([a-fA-F0-9]{2})/.exec(f)){return[parseInt(e[1],16),parseInt(e[2],16),parseInt(e[3],16)]}if(e=/#([a-fA-F0-9])([a-fA-F0-9])([a-fA-F0-9])/.exec(f)){return[parseInt(e[1]+e[1],16),parseInt(e[2]+e[2],16),parseInt(e[3]+e[3],16)]}if(e=/rgba\(0, 0, 0, 0\)/.exec(f)){return a.transparent}return a[d.trim(f).toLowerCase()]}function c(g,e){var f;do{f=d.curCSS(g,e);if(f!=""&&f!="transparent"||d.nodeName(g,"body")){break}e="backgroundColor"}while(g=g.parentNode);return b(f)}var a={aqua:[0,255,255],azure:[240,255,255],beige:[245,245,220],black:[0,0,0],blue:[0,0,255],brown:[165,42,42],cyan:[0,255,255],darkblue:[0,0,139],darkcyan:[0,139,139],darkgrey:[169,169,169],darkgreen:[0,100,0],darkkhaki:[189,183,107],darkmagenta:[139,0,139],darkolivegreen:[85,107,47],darkorange:[255,140,0],darkorchid:[153,50,204],darkred:[139,0,0],darksalmon:[233,150,122],darkviolet:[148,0,211],fuchsia:[255,0,255],gold:[255,215,0],green:[0,128,0],indigo:[75,0,130],khaki:[240,230,140],lightblue:[173,216,230],lightcyan:[224,255,255],lightgreen:[144,238,144],lightgrey:[211,211,211],lightpink:[255,182,193],lightyellow:[255,255,224],lime:[0,255,0],magenta:[255,0,255],maroon:[128,0,0],navy:[0,0,128],olive:[128,128,0],orange:[255,165,0],pink:[255,192,203],purple:[128,0,128],violet:[128,0,128],red:[255,0,0],silver:[192,192,192],white:[255,255,255],yellow:[255,255,0],transparent:[255,255,255]}})(jQuery);

    var $d = $(document);
    var may = function(o,f) {return f ? f.bind(o) : function() {}};

    $.extend(true, $[deck].defaults, {
        selectors: {
            animShow: ".anim-show",
            animHide: ".anim-hide",
            animAddClass: ".anim-addclass",
            animRemoveClass: ".anim-removeclass",
            animAttribute: ".anim-attribute",
            // specific ones
            animPlay: ".anim-play",
            animPause: ".anim-pause",
            animViewboxAs: ".anim-viewboxas",
            //
            animContinue: ".anim-continue"
        },
        anim: {
            duration: 400
        }
    });

    var waitFor = 0
    $[deck]('extend', 'animWaitMore', function(){ waitFor++ });
    $[deck]('extend', 'animWaitLess', function(){ waitFor-- });

    var doInitIfReady = function hoho() {
        if (waitFor>0) {
            setTimeout(doInitIfReady, 10) // retry until all is loaded
            return;
        }
        // first we define some tools and grab some info from deck.js
        var o = $[deck]('getOptions');
        var context = function(el) {
            return {
                what: function() {return $(el).attr("data-what")},
                dur: function() {return $(el).attr("data-dur")*1 || o.anim.duration},
                classs: function() {return $(el).attr("data-class")},
                attribute: function() {return $(el).attr("data-attr").split(':')[0]},
                as: function() {return $(el).attr("data-as")},
                value: function() {return $(el).attr("data-attr").split(':')[1]},
                toplevel: function() {return $[deck]('getToplevelSlideOf', el).node},
                all: function() {return $(this.what(),this.toplevel())}
            }
        };
        var classical = function(selector, methods) {
            $(selector).each(function(i, el) {
                var c = context(el);
                may(methods, methods.create)(c);
                $(el).bind('deck.toplevelBecameCurrent', function(_, direction) {
                    may(methods, methods.init)(c);
                }).bind('deck.afterToplevelBecameCurrent', function(_, direction) {
                    may(methods, methods.fast)(c);
                }).bind('deck.lostCurrent', function(_, direction, from, to) {
                    if (direction == 'forward' || Math.abs(from - to)>1 ) return; // if a big step, let the "step" extension do its job
                    may(methods, methods.undo)(c);
                }).bind('deck.becameCurrent', function(_, direction, from, to) {
                    if (direction == 'reverse' || Math.abs(from - to)>1 ) return; // if a big step, let the "step" extension do its job
                    may(methods, methods.doit)(c);
                });
            });
        };
        
        // here come the real animations
        classical(o.selectors.animShow, {
            init: function(c) {c.all().animate({'opacity': 0.}, 0)},
            undo: function(c) {c.all().animate({'opacity': 0.}, c.dur()/100)},
            doit: function(c) {c.all().animate({'opacity': 1.}, c.dur())},
            fast: function(c) {c.all().animate({'opacity': 1.}, 0)}
        });
        classical(o.selectors.animHide, {
            init: function(c) {c.all().animate({'opacity': 1.}, 0)},
            undo: function(c) {c.all().animate({'opacity': 1.}, c.dur()/100)},
            doit: function(c) {c.all().animate({'opacity': 0.}, c.dur())},
            fast: function(c) {c.all().animate({'opacity': 0.}, 0)}
        });
        classical(o.selectors.animAddClass, {
            init: function(c) {c.all().removeClass(c.classs())},
            undo: function(c) {c.all().removeClass(c.classs())},
            doit: function(c) {c.all().addClass(c.classs())},
            fast: function(c) {c.all().addClass(c.classs())}
        });
        classical(o.selectors.animRemoveClass, {
            init: function(c) {c.all().addClass(c.classs())},
            undo: function(c) {c.all().addClass(c.classs())},
            doit: function(c) {c.all().removeClass(c.classs())},
            fast: function(c) {c.all().removeClass(c.classs())}
        });
        classical(o.selectors.animAttribute, {
            init: function(c) {
                c.previousElement = [];
                c.all().css(c.attribute(), '') // for the jquery anim to work the css attribute should not be defined in the element (in the html) so we suppose it is empty by default (and thus, if it is not empty, it means it has been set by jquery)
            },
            undo: function(c) {
                var k = c.attribute()
                for (i in c.previousElement) { // use the saved list of elements and values
                    var whatTo = {}
                    whatTo[k] = c.previousCss[i]
                    $(c.previousElement[i]).animate(whatTo, 0)
                }
            },
            doit: function(c, factor) {
                if (factor === undefined) factor = 1
                var k = c.attribute()
                c.previousCss = []
                c.previousElement = []
                c.all().each( function(){c.previousElement.push(this); c.previousCss.push($(this).css(k))}) // save a list of elements and values
                var whatTo = {}
                whatTo[c.attribute()] = c.value()
                c.all().animate(whatTo, c.dur()*factor)
            },
            fast: function(c) {this.doit(c,0)}
        });
        classical(o.selectors.animPlay, {
            init: function(c) {c.all().each(function(){this.pause(); try{this.currentTime=0}catch(e){} })},
            undo: function(c) {c.all().each(function(){this.pause()})},
            doit: function(c) {c.all().each(function(){this.play()})},
            fast: function(c) {c.all().each(function(){this.play()})}
        });
        classical(o.selectors.animPause, {
            undo: function(c) {c.all().each(function(){this.play()})},
            doit: function(c) {c.all().each(function(){this.pause()})},
            fast: function(c) {c.all().each(function(){this.pause()})}
        });
        classical(o.selectors.animViewboxAs, {
            create: function(c) {c.whatFrom = {}},
            init: function(c) {this.undo(c)},
            undo: function(c) {c.all().animate(c.whatFrom, 0)},
            doit: function(c, factor) {
                if (factor === undefined) factor = 1
                var attr = "svgViewBox";
                var whatTo = {};
                var asWhat = $(c.as());
                var a = function (i) {return asWhat.attr(i)}
                // todo should do as with the generic attribute above (maintain a list)
                c.whatFrom[attr] = c.all().first().get(0).attributes.getNamedItem('viewBox').nodeValue // custom access to the svg viewbox attribute
                var toViewBox = a('x')+" "+a('y')+" "+a('width')+" "+a('height');
                whatTo[attr] = toViewBox;
                c.all().animate(whatTo, c.dur()*factor)
            },
            fast: function(c) {this.doit(c, 0)}
        });
        classical(o.selectors.animContinue, {
            doit: function(c) {setTimeout(function(){$[deck]('next')}, 1)}
            // do not do it in fast mode
        });
        // handle the chained undo for "anim-continue"
        $(o.selectors.animContinue).each(function(i, curSlide) {
            $(curSlide).bind('deck.becameCurrent', function(_, direction) {
                if (direction == 'forward') return;
                setTimeout(function(){$[deck]('prev')}, 1)
            });

        });

        // finally force "refresh" (notification of slide change)
        var current = $[deck]('getSlide')
        var icur = 0
        for (; icur < $[deck]('getSlides').length; icur++) {
            if ($[deck]('getSlides')[icur] == current) break;                
        }
	$d.trigger("deck.change", [icur, 0]);
	$d.trigger("deck.change", [0, icur]);

    }
    $(document).bind('deck.init', function() {
        setTimeout(doInitIfReady, 10) // try the first time after init
    });
        
})(jQuery, 'deck');

/*!
Deck JS - deck.svg
Copyright (c) 2012 Rémi Emonet, as a major refactor from an early version from Rémi Barraquand.
*/

/*
This module provides a support for managed svg inclusion (allowing proper DOM access subsequently for animations, etc.).
*/

(function($, deck, undefined) {
    var $d = $(document);
    var may = function(f) {return f ? f : function() {}};

    $.extend(true, $[deck].defaults, {
        classes: {
            svgPlaceholder: 'deck-svg'
        }
    });

    /*
      jQuery.deck('Init')
    */
    $d.bind('deck.init', function() {
        var opts = $[deck]('getOptions');
        var container = $[deck]('getContainer');

        /*
          Load parameters from an Object element
        */
        var loadObjectParams = function(objectElement) {
            var attributes = {};
            $(objectElement).children("param").each(function(index){
                attributes[$(this).attr("name")] = $(this).attr("value");
            });
            return attributes;
        }
        
        /*
          Return true if default params are set.
        */
        var validateParams = function(params) {
            return params['src'];// && params['width'] && params['height'];// && params['animator'];
        }
        
        /*
          Create SVG placeholder
        */
        var createSVG = function(object, attributes) {
            var $canvas, $control, $next, $reload, $placeholder;
            
            /* Create svg canvas */
            $canvas = $("<div />").attr({
                'id':  $(object).attr('id'),
                'class': opts.classes.svgPlaceholder + " " + $(object).attr('class')
            }).css({
                'height': attributes['height'],
                'width': attributes['width']
            });
            return $canvas;
        }

        
        /* Go through all toplevel slides */
        $($[deck]('getSlides')).each( function(i, $el) {
            var $slide = $[deck]('getSlide', i);

            /*
            if ($slide.has("object[type='deckjs/svg']").length>0) {
                $slide.data('animators', new Array());
            }*/
            
            /* Find all the object of type deckjs/svg */
            if ($slide == null) return true;
            $slide.find("object[type='deckjs/svg']").each(function(index, obj) {
                //var id = $(this);
                /* Load attributes and validate them */
                var attributes = loadObjectParams(obj);
                if (!validateParams(attributes) ) {
                    throw "Error while initializing "+$(obj).attr('id')+", please ensure you have setup the required parameters."
                    return false;
                }
                
                /* Add this animator to the list of animators of the current slide. */
                //$slide.data('animators').push(attributes['animator']);
                
                /* Create SVG placeholder */
                var SVG = createSVG(obj, attributes);
                $(obj).replaceWith(SVG);
                
                // Finaly load the SVG data
                //$[deck]('addLoading');
                $[deck]("animWaitMore");
                SVG.svg({
                    loadURL: attributes['src'],
                    onLoad: function($svg, w, h) {
                        var aa = $($svg.root());
                        if (aa.attr('viewBox') == undefined) {
                            var to = "0 0 " + w + " " + h;
                            $svg.root().setAttribute("viewBox", to);
                            aa.attr("svgViewBox", to);
                            if (attributes['stretch'] == 'true') $svg.root().setAttribute('preserveAspectRatio', "none");
                        }
                        $[deck]("animWaitLess");
                        /*
                          $[deck]('removeLoading')
                        */
                    }
                });
            });
        });
    })
    
    
})(jQuery, 'deck');

