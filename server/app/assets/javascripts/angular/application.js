  var language = 'ia';

  var fullThumbSize = 50;
  var halfThumbSize = fullThumbSize / 2;
  var borderWidth = 1; // px
  var photoWidth = fullThumbSize;
  var photosPerRequest = 20;
  var navbarElementPixelWidth = 60; // pixels

  // TODO Get these two aligned.
  var minFaceDimension = 20; // Pixels TODO Scale to photo
  var minFaceDimensionPixels = 24; // This is what the UI shows (it actually includes 2xborderWidth!)

  var handleRadius = 5; // px
  var handleWidth = 2 * handleRadius; // px

  var faceNameHideTimeout = 1200

  var mugmarkerServices = angular.module('mugmarkerServices', ['ngResource']);

  var blank = function(stringValue)
  {
    return (typeof(stringValue) == 'undefined' ||
            stringValue === null ||
            stringValue.trim().length === 0)
  }
  mugmarkerServices.factory('Photo',
                            ['$resource',
                              function($resource)
                              {
                                return $resource('/api/v1/photos/:id.json',
                                                 {a_id: 1 },
                                                 {
                                                    update:
                                                    {
                                                      method: "PUT",
                                                      params: {id: "@id"}
                                                    }
                                                  }
                                );
                              }
                             ]
  );
  mugmarkerServices.factory('Face',
                            ['$resource',
                              function($resource)
                              {
                                return $resource('/api/v1/faces/:id.json',
                                                 {a_id: 1},
                                                 {
                                                    update:
                                                    {
                                                      method: "PUT",
                                                      params: {id: "@id"} // The face Id
                                                    },
                                                    restore:
                                                    {
                                                      url: "/api/v1/faces/:id/restore.json",
                                                      method: "POST",
                                                      params: {id: "@id"} // The face Id
                                                    }

                                                  }
                                );
                              }
                             ]
  );
  mugmarkerServices.factory('Name',
                          ['$resource',
                            function($resource)
                            {
                              return $resource('/api/v1/names/:id.json',
                                               {a_id: 1},
                                               {
                                                  update:
                                                  {
                                                    method: "PUT",
                                                    params: {id: "@id"} // The name Id
                                                  }
                                                }
                              );
                            }
                           ]
  );
  mugmarkerServices.service('NameToPhotoGlue',
                            [function()
                              {
                                var withNoteFunction = function(obj)
                                                       {
                                                          obj.withNote = blank(obj.note) ? obj.publicName
                                                                                         : obj.publicName + ' (' + obj.note + ')';
                                                       }
                                // This just transfers the scope of the photo
                                this.setPhotoScope = function(photoScope)
                                {
                                  this.photoScope = photoScope;
                                }
                                // This is commuicating with the controller that shows the nav
                                this.setPhotoNavScope = function(photoNavScope)
                                {
                                  this.photoNavScope = photoNavScope;
                                  // If the photoScope is already present, send it back
                                  if (this.photoScope && this.photoScope.photo)
                                  {
                                    this.photoNavScope.setPhoto(this.photoScope.photo);
                                  }
                                }
                                this.updatePhotoToNavScope = function(photo)
                                {
                                  if (this.photoNavScope)
                                  {
                                    this.photoNavScope.setPhoto(photo);
                                  }
                                }
                                // This just sets the names in this context
                                this.setNamesIndex = function(namesIndex)
                                {
                                  this.names = {};
                                  that = this;
                                  angular.forEach(namesIndex, function(nameRecord)
                                                              {
                                                                withNoteFunction(nameRecord);
                                                                that.names[nameRecord['id']] = nameRecord;
                                                              }
                                                  );
                                }


                                // This gets the names that are already loaded
                                this.getNamesIndex = function()
                                {
                                  return this.names;
                                }

                                // This indicates whether the names index has been initialized
                                this.namesIndexInitialized = function()
                                {
                                  return !!this.names;
                                }

                                // This translates a face ID to a name
                                this.getPrivateName = function(namedFaceId)
                                {
                                  face = this.names[namedFaceId];
                                  return face ? face.privateName : undefined;
                                }

                                this.mergeNewFacedata = function(newNames)
                                {
                                  for (var id in newNames)
                                  {
                                    this.names[id] = newNames[id];
                                    withNoteFunction(this.names[id]);
                                  }
                                }

                                // This records a particular face and clears the selected name
                                this.setFace = function(face)
                                {
                                  this.selectedFace = face;
                                }

                                // This method accepts a name, which will be sent to the
                                // server to create a new record, and that record will
                                // then be associated with the current face frame.
                                this.applyNewName = function(nameNeedle)
                                {
                                  this.photoScope.updateFace(this.selectedFace, nameNeedle);
                                }

                                // This is called after a name in the list is clicked,
                                // setting the name ID for the face that was just clicked
                                this.setName = function(name)
                                {
                                  this.photoScope.setHoverFace(this.selectedFace);
                                  this.selectedFace.namedFaceId = name.id;
                                }

                                //
                              }
                             ]
  );
  mugmarkerServices.service('PhotoSliderCache',
                            ['$http',
                              function($http)
                              {
                                this.cache = [];
                                this.loaded = {};
                                var that = this;
                                this.getTotalPhotos = function() { return this.totalPhotos };
                                this.getPhotos = function() { return this.cache };
                                this.updatePhotos = function(fromIndex, toIndex)
                                                 {
                                                   var promises = [];
                                                   for (var i = fromIndex; i <= toIndex; i += photosPerRequest)
                                                   {
                                                     var page = Math.floor(i / photosPerRequest);
                                                     if (!that.loaded[page])
                                                     {
                                                       var url = '/api/v1/photos.json?a_id=1&n=' + photosPerRequest + '&i=' + page;
                                                       var promise = $http.get(url)
                                                                          .then(function(response)
                                                                                {
                                                                                  that.loaded[response.data.page] = true;
                                                                                  that.totalPhotos = response.data.totalPhotos;
                                                                                  angular.forEach(response.data.photos, function(photo)
                                                                                                            {
                                                                                                              var scaleFactor = fullThumbSize / Math.max(photo.width, photo.height);
                                                                                                              var smaller = (fullThumbSize * scaleFactor);
                                                                                                              if (photo.width > photo.height)
                                                                                                              {
                                                                                                                photo.thumbStyle = {width: fullThumbSize + 'px', height: (photo.height * scaleFactor) + 'px'};
                                                                                                              }
                                                                                                              else
                                                                                                              {
                                                                                                                photo.thumbStyle = {height: fullThumbSize + 'px', width: (photo.width * scaleFactor) + 'px'};
                                                                                                              }
                                                                                                              photo.divStyle = {left: (photo.index * navbarElementPixelWidth) + 'px', position: 'absolute', top: 0, display: 'inline-block'};
                                                                                                              that.cache.push(photo);
                                                                                                            });
                                                                                },
                                                                                function(response, status, headers, config)
                                                                                {
                                                                                  alert('An error occurred (' + status + '). Please try again.');
                                                                                });
                                                       promises.push(promise);
                                                     }
                                                   }
                                                   return promises;
                                                 };
                              }
                            ]
  );

  var app = angular.module('mugmarker', ['ui.router', 'mugmarkerServices']);

  // Configure the router (ui-router)
  app.config(['$stateProvider', '$urlRouterProvider',
    function($stateProvider, $urlRouterProvider)
    {
      $urlRouterProvider.otherwise('/');
      $stateProvider
        .state('photos',
                {
                  url:'/photos',
                  views:
                  {
                    display:
                    {
                      templateUrl: '/templates/photos.html',
                      controller: 'PhotoController'
                    },
                    navspecific:
                    {
                      templateUrl: '/templates/photos.nav.html',
                      controller: 'PhotoNavController'
                    },
                    navline2:
                    {
                      templateUrl: '/templates/photos.navslider.html',
                      controller: 'PhotoNavSliderController'
                    }
                  }
                }
              )
        .state('photos.edit',
                {
                  url:'/edit/:id',
                  templateUrl: '/templates/photos.edit.html',
                  controller: 'PhotoController'
                }
              )
        .state('photos.detail',
                {
                  url:'/detail/:id',
                  templateUrl: '/templates/photos.detail.html',
                  controller: 'DetailController'
                }
              )
        .state('names',
                {
                  url:'/names',
                  views:
                  {
                    display:
                    {
                      templateUrl: '/templates/names.html',
                      controller: 'NamesController'
                    },
                    navspecific:
                    {
                      templateUrl: '/templates/names.nav.html',
                      controller: 'NameNavController'
                    },
                    navline2:
                    {
                      templateUrl: '/templates/names.navslider.html',
                      controller: 'NamesNavSliderController'
                    }
                  }
                }
              )
        .state('names.list',
                {
                  url:'/list',
                  templateUrl: '/templates/names.list.html',
                }
              )
        .state('names.show',
                {
                  url:'/show/:id',
                  templateUrl: '/templates/names.show.html',
                  controller: 'NameController'
                }
              )
    }
  ]);


  app.service('translations', function()
  {
    var translations =
    {
      en: {
            confirmDeleteFace: 'Do you really want to delete this frame?',
            deleteFace: 'Delete frame',
            detailsButton: 'Details',
            errorApplyingChange: 'An error occurred and the change you made could not be saved.',
            markPhoto: 'Mark or unmark this photo for later attention',
            people: 'People',
            photoButton: 'Photo',
            photos: 'Photos',
            restoreButton: 'Restore Frames',
            tryAgain: 'An error occurred. Please try again.',
            unableToAddFace: 'An error occurred and the frame could not be added.',
            unableToDeleteFace: 'An error occurred and the frame could not be deleted.',
            unableToGetRelatedPhotos: 'An error occured and the photos for this person could not be obtained.',
            unableToRestoreFace: 'An error occured and the frame could not be restored.',
            unknown: 'Unknown',
            updatedAt: 'Updated at',
          },
      ia: {
            confirmDeleteFace: 'Oday youway eallyray antway otay eleteday isthay amefray?',
            deleteFace: 'Eleteday Amefray',
            detailsButton: 'Etailsday',
            errorApplyingChange: 'Anway errorway occurredway andway ethay angechay ouyay ademay ouldcay otnay ebay avedsay..',
            markPhoto: 'Arkmay or unmarkway isthay otophay orfay aterlay attentionway',
            people: 'Eoplepay',
            photos: 'Otosphay',
            photoButton: 'Otophay',
            restoreButton: 'Estoreray Amesfray',
            tryAgain: 'Anway errorway occurredway. Easeplay ytray againway.',
            unableToAddFace: 'Anway errorway occurredway andway ethay amefray ouldcay otnay ebay addedway.',
            unableToDeleteFace: 'Anway errorway occurredway andway ethay amefray ouldcay otnay ebay eletedday.',
            unableToGetRelatedPhotos: 'Anway errorway occurredway andway ethay otosphay orfay isthay ersonpay ouldcay otnay obtainedway.',
            unableToRestoreFace: 'Anway errorway occurredway andway ethay amefray ouldcay otnay ebay estoredray.',
            unknown: 'Otnay Ownknay',
            updatedAt: 'Updatedway atway',
          },
      };

    return {
      setLanguage: function(newLang)
      {
        language = newLang;
      },
      translate: function(key)
      {
        if (!translations[language])
        {
          return 'Missing language "' + language + '"';
        }
        if (!translations[language][key])
        {
          // TODO send an alert
          return 'Missing translation for "' + key + '"';
        }
        return translations[language][key];
      }
    };
  });

  // mmMovable: not really draggable (no drop needed), with a containment rectangle specified
  // derived from https://docs.angularjs.org/guide/directive (see "Creating a Directive that Adds Event Listeners")

  var calculateContainment = function(ele, behavior)
  {
    // All of the containment is in browser coordinates and is taken from the
    // browser elements. This ensures that what the user sees is going to be
    // contained within the elements that are shown on the screen. Otherwise
    // there's a slight risk the browser display with be off by a pixel (or
    // a pixel-fraction on retina displays). I know that is un-angular in concept,
    // but that's how it works for now.

    var result;
    var photoEle = $('#photo-img');
    var photoWidth = photoEle.width();
    var photoHeight = photoEle.height();

    if (behavior == "move")
    {
      // The containment is a set of coordinates RELATIVE TO THE STARTING POSITION
      // of the top left corner of the frame, defining from that origin, how far
      // the the mouse can move (beyond which the mouse may move, but its motion is ignored).
      var frameEle = $(ele);
      result =  {
                  top:    0,
                  left:   0,
                  right:  photoEle.width() - frameEle.outerWidth(),
                  bottom: photoEle.height() - frameEle.outerHeight(),
                }
    }
    else if (behavior == "resize")
    {
      // For this, the calculations are more complex. The "top" value is the smaller of
      // the distance from the top of the photo to the top of the frame and
      // the distance from the bottom of the photo and the bottom of the frame.
      // That number must then be subtracted from the starting position of the frame top.
      // The logic for the left is the same, except it involves the "x" axis.

      // The right and bottom points are the centerpoint of the frame.
      var frameEle = $(ele).parent();
      var framePos = frameEle.position();
      result =  {
                  top:    framePos.top -
                          Math.min(framePos.top, photoEle.height() - (framePos.top + frameEle.outerHeight())),
                  left:   framePos.left -
                          Math.min(framePos.left, photoEle.width() - (framePos.left + frameEle.outerWidth())),
                  right:  framePos.left + ((frameEle.width() - minFaceDimensionPixels) / 2),
                  bottom: framePos.top + ((frameEle.height() - minFaceDimensionPixels) / 2),
                };
      result.maxW = (2 * (result.right - result.left)) + minFaceDimensionPixels;
      result.maxH = (2 * (result.bottom - result.top)) + minFaceDimensionPixels;
    }
    else
    {
      console.log('Unexpected behavior ' + '"' + behavior + '"');
      return;
    }
    result.constrainX = function(x) { return Math.min(Math.max(x, result.left), result.right); };
    result.constrainY = function(y) { return Math.min(Math.max(y, result.top), result.bottom); };
    result.constrainW = function(w) { return Math.min(Math.max(w, minFaceDimensionPixels), result.maxW); };
    result.constrainH = function(h) { return Math.min(Math.max(h, minFaceDimensionPixels), result.maxH); };
    return result;
  }

  app.directive('mmMovable',
                [ '$document',
                  function($document, $scope)
                  {
                    return {
                      scope:
                      {
                        face: '=mmMovable',
                        behavior: '@mmMovableBehavior',
                        containment: '=mmMovableContainment',
                        photo: '=mmMovablePhoto'
                      },
                      link: function(scope, element, attr, ctrl)
                      {
                        var containment; // Keeps track of where the top-left corner of the frame can move to.

                        // These the starting position of the cursor at the mousedown event
                        var mouseX, mouseY;

                        // These are the starting position of the top-left corner of the face frame
                        // in the *photo* coordinate space.
                        var initialX, initialY, initialH, initialW;

                        element.on('mousedown', function(event) {
                          event.preventDefault(); // Prevent default dragging of selected content
                          event.stopPropagation(); // The handle is nested in the frame, so it fires 2x
                          if (scope.face.manual) // Otherwise the "move" option remains available to all faces
                          {
                            mouseX = event.pageX;
                            mouseY = event.pageY;
                            initialX = scope.photo.scaled(scope.face.x);
                            initialY = scope.photo.scaled(scope.face.y);
                            initialW = scope.photo.scaled(scope.face.w);
                            initialH = scope.photo.scaled(scope.face.h);

                            containment = calculateContainment(element, scope.behavior);

                            $document.on('mousemove', mousemove);
                            $document.on('mouseup', mouseup);
                          }
                        });

                        function mousemove(event) {
                          var newX, newY, newW, newH;
                          var deltaX = event.pageX - mouseX;
                          var deltaY = event.pageY - mouseY;

                          if (scope.behavior == 'resize')
                          {
                            newX = initialX - (event.pageX - mouseX);
                            newY = initialY - (event.pageY - mouseY);
                            newX = containment.constrainX(newX);
                            newY = containment.constrainY(newY);
                            scope.face.x = scope.photo.unscaled(newX);
                            scope.face.y = scope.photo.unscaled(newY);

                            newW = initialW + (2 * (event.pageX - mouseX));
                            newH = initialH + (2 * (event.pageY - mouseY));
                            newW = containment.constrainW(newW);
                            newH = containment.constrainH(newH);
                            scope.face.w = scope.photo.unscaled(newW);
                            scope.face.h = scope.photo.unscaled(newH);
                          }
                          else if (scope.behavior == 'move')
                          {
                            newX = initialX + event.pageX - mouseX;
                            newY = initialY + event.pageY - mouseY;
                            newX = containment.constrainX(newX);
                            newY = containment.constrainY(newY);
                            scope.face.x = scope.photo.unscaled(newX);
                            scope.face.y = scope.photo.unscaled(newY);
                          }

                          scope.$apply();
                        }

                        function mouseup() {
                          $document.off('mousemove', mousemove);
                          $document.off('mouseup', mouseup);
                        }
                      }
                    };
                  }
                ]
  );

  // mmNameEntry: support the entry of a name from the specified elment by obscuring it
  // with the #name field.

  app.directive('mmNameEntry',
                [ 'NameToPhotoGlue',
                  function(NameToPhotoGlue)
                  {
                    return {
                      scope:
                      {
                        face: '=mmNameEntry',
                      },
                      link: function(scope, element, attr, ctrl)
                      {
                        var ele = element[0]; // extract the actual element
                        element.on('click', function(event)
                                            {
                                              NameToPhotoGlue.setFace(scope.face);
                                              var targetPosition = $(ele).offset();
                                              targetPosition.top -= 1;  // $borderWidth
                                              targetPosition.left -= 1; // $borderWidth

                                              // TODO It would be much better to clear the value of the
                                              // #name field by setting the nameNeedle to ''
                                              $('#name').val('').css(targetPosition).show();
                                              $('#name-entry-box').focus();
                                            });
                      }
                    }
                  }
                ]
  );

  app.factory('Page', function() {
     var title = 'Mugmarker';
     return {
       title: function() { return title; },
       setTitle: function(newTitle) { title = newTitle }
     };
  });

  app.controller('PageController',
                  // NOTE: Because these are injected at this level, and associated
                  //       with the $scope, all subordinate controllers have access
                  //       to them.
                  ['$scope', 'Page', 'PhotoSliderCache', 'translations',
                    function($scope, Page, PhotoSliderCache, translations)
                    {
                      $scope.Page = Page;
                      $scope.xlate = translations.translate;
                                      }
  ]);

  app.controller('DetailController',
                  ['$scope', '$stateParams', '$http',
                    function($scope, $stateParams, $http)
                    {
                      $scope.Page.setTitle('DetailController');
                      $http.get('#{details_api_v1_photos_path(format: :json)}?a_id=1&id=' + $stateParams.id )
                           .success(function(response)
                                    {
                                      $scope.photo = {id: $stateParams.id}; // To support navigation in partial
                                      $scope.details = response;
                                    })
                      $scope.detailsAsJson = function()
                      {
                        return angular.toJson($scope.details, true);
                      }
                    }
  ]);


  // This method provides a unique ID on each DOM object for which it is invoked.
  // It's needed for the timers so they can be associated with a face-frame.
  (function() {
    var id_counter = 1;
    Object.defineProperty(Object.prototype, "__uniqueId", {
        writable: true
    });
    Object.defineProperty(Object.prototype, "mmuid", {
        get: function() {
            if (this && (this.__uniqueId == undefined))
                this.__uniqueId = id_counter++;
            return this.__uniqueId;
        }
    });
  })();

  var timers = {};
  debounce = function(obj, milliseconds, func)
  {
    var args = arguments;
    clearTimeout(timers[obj.mmuid]);
    timers[obj.mmuid] = setTimeout(function()
                             {
                               func.apply(obj, args);
                               timers[obj.mmuid] = null;
                             },
                             milliseconds);
  }

  app.controller('NamesNavSliderController',
                 ['$scope', 'NameToPhotoGlue',
                  function($scope, NameToPhotoGlue)
                  {
                    $scope.setSelectedName = function(name)
                    {
                      $scope.name = name;
                      NameNavController.setName(name); // Propogate to the related controller
                    };
                    $scope.names = NameToPhotoGlue.getNamesIndex();
                  }
                ]
  );

  app.directive('mmScroll', function () {
      return {
          restrict: 'A',
          leftPos: 0,
          link: function (scope, element, attrs) {
              var raw = element[0];
              element.bind('scroll', function () {
                  this.leftPos = raw.scrollLeft;
                  this.mmuid; // Just need to call this once to assign it
                  debounce(this, 500, scope.scrolledTo)
              });
          }
      };
  });

  app.controller('PhotoNavSliderController',
                 ['$scope', 'PhotoSliderCache',
                  function($scope, PhotoSliderCache)
                  {
                    $scope.photoScrollerWidth = 1000; // intial value
                    $scope.$watch("photoScrollerWidth",function(){
                      $scope.scrollerWidthProperty = { width: $scope.photoScrollerWidth + 'px' };
                    });
                    $scope.setSelectedPhoto = function(thumb)
                    {
                      $scope.photo = thumb;
                    };

                    $scope.scrolledTo = function(scroller) {
                      var first = Math.floor(scroller.leftPos / navbarElementPixelWidth);
                      var last = first + Math.floor($('.navbar-slider-container').width() / navbarElementPixelWidth) + 1;
                      PhotoSliderCache.updatePhotos(first, last);
                    };
                    $scope.thumbnails = PhotoSliderCache.getPhotos();
                    // To get started, we need some number of photos
                    var initialRequest = Math.ceil($('.navbar-slider-container').width() / navbarElementPixelWidth);
                    var promises = PhotoSliderCache.updatePhotos(0, initialRequest); // Prime the pump
                    var promise = promises[0] // Any promise will do, we just need the totalPhotos
                    if (promise) 
                    {
                      promise.then(function(d)
                                   {
                                     $scope.photoScrollerWidth = PhotoSliderCache.getTotalPhotos() * navbarElementPixelWidth;
                                   },
                                   function(data, status, headers, config)
                                   {
                                     // TODO Check this function, because I think it has the wrong signature
                                     alert('An error occurred (' + status + '). Please try again.');
                                   }

                      );
                    }
                  } 
                 ]
  );

  app.controller('NameNavController',
                 ['$scope',
                  function($scope)
                  {
                    $scope.setName = function(name)
                                      {
                                        $scope.name = name;
                                      };
                  }
                ]
  );

  app.controller('PhotoNavController',
                 ['$scope', 'NameToPhotoGlue', 'Face',
                  function($scope, NameToPhotoGlue, Face)
                  {
                    NameToPhotoGlue.setPhotoNavScope($scope);
                    $scope.setPhoto = function(photo)
                                      {
                                        $scope.photo = photo;
                                      };
                    $scope.restoreFace = function(face)
                                         {
                                           Face.restore({photo_id: face.photoId, id: face.id},
                                                        function(data)
                                                        {
                                                          NameToPhotoGlue.mergeNewFacedata(data.names);
                                                          face.deleted = data.face.deleted; // FALSE
                                                        },
                                                        function(err)
                                                        {
                                                          $window.alert($scope.xlate('unableToRestoreFace'));
                                                        });
                                         };
                  }
                ]
  );

  app.controller('PhotoController',
                 ['$scope', '$stateParams', '$window', 'Photo', 'Face', 'NameToPhotoGlue',
                  function($scope, $stateParams, $window, Photo, Face, NameToPhotoGlue)
                  {
                    $scope.Page.setTitle($scope.xlate('photos'));
                    NameToPhotoGlue.setPhotoScope($scope);
                    var maxDim = 500; // pixels
                    var scaleFactor; // updated when the Photo object is loaded
                    $scope.listeners = [];

                    var defineScaledMethods = function(whichFace)
                    {
                      whichFace.scaledX = function() {return (this.x * scaleFactor) + 'px';};
                      whichFace.scaledY = function() {return (this.y * scaleFactor) + 'px';};
                      whichFace.scaledW = function() {return (this.w * scaleFactor) + 'px';};
                      whichFace.scaledH = function() {return (this.h * scaleFactor) + 'px';};
                      // "8" in the following has to do with the diameter of the handle
                      whichFace.handleY = function() {return (this.h * scaleFactor - 8) + 'px';};
                      whichFace.handleX = function() {return (this.w * scaleFactor - 8) + 'px';};
                      whichFace.thumbDataUri = function()
                                               {
                                                 if ((!this.thumbnail) || (this.thumbnail.length === 0))
                                                 {
                                                   return null;
                                                 }
                                                 else
                                                 {
                                                   return this.thumbnail;
                                                 }
                                               }
                      whichFace.displayName = NameToPhotoGlue.getPrivateName(whichFace.namedFaceId);
                      whichFace.photoId = photo.id;
                      whichFace.mmuid   // Assign a unique ID so the first debounce does not trigger an update
                      var listener = $scope.$watch('photo.faces[' + $scope.listeners.length + ']',
                                                   faceResizeMoveOrNameChange,
                                                   true);
                      $scope.listeners.push(listener); // Hold onto it so it is possible to unbind it.
                    };
                    // TODO How does this work? Where does "photo" in the function get defined?
                    var photo = Photo.get({ id: $stateParams.id }, function() {
                      scaleFactor = maxDim / Math.max(photo.width, photo.height);

                      // "unscaled()" converts from browser coordinates to photo coordinates
                      photo.unscaled = function(rawValue) {return Math.floor(rawValue / scaleFactor);}

                      // "scaled()" converts from photo coordinates to browser coordinates
                      photo.scaled =   function(rawValue) {return Math.floor(rawValue * scaleFactor);}
                      photo.workingImageHeight = function() {return photo.height * scaleFactor + 'px'};
                      photo.workingImageWidth  = function() {return photo.width * scaleFactor + 'px'};
                      photo.mmuid; // Assign a unique ID so the first debounce does not trigger an update
                      angular.forEach(photo.faces, defineScaledMethods);
                      $scope.photo = photo;
                      NameToPhotoGlue.updatePhotoToNavScope(photo);

                    }); // get() returns a single photo

                    $scope.addFaceAt = function(x, y)
                    {
                      // We must convert the coordinates back to that of the original photo
                      var unscaledX = $scope.photo.unscaled(x);
                      var unscaledY = $scope.photo.unscaled(y);

                      // We calculate the average width and height of visible faces
                      var sumW = 0;
                      var sumH = 0;
                      var defaultFaceDimension = Math.min($scope.photo.width, $scope.photo.height) / 10;
                      var meanWidth = minFaceDimension;
                      var meanHeight = minFaceDimension;
                      var n = 0;
                      var fs = $scope.photo.faces
                      for (var i = 0; i < fs.length; i++)
                      {
                        // Skip the logically deleted faces
                        if (!fs[i].deleted)
                        {
                          sumW += fs[i].w;
                          sumH += fs[i].h;
                          n += 1;
                        }
                      }
                      if (n > 0)
                      {
                        meanWidth = sumW / n;
                        meanHeight = sumH / n;
                      }
                      else
                      {
                        meanWidth = defaultFaceDimension;
                        meanHeight = defaultFaceDimension;
                      }

                      meanWidth = Math.max(meanWidth, minFaceDimension);
                      meanHeight = Math.max(meanHeight, minFaceDimension);
                      var face = {
                                  x: unscaledX - (meanWidth / 2),
                                  y: unscaledY - (meanHeight / 2),
                                  w: meanWidth,
                                  h: meanHeight,
                                  photoId: $scope.photoId,
                                  deleted: false,
                                  manual: true,
                                  id: null,
                                  namedFaceId: null,
                                };
                      defineScaledMethods(face);
                      if ((0 < face.x) && (face.x < ($scope.photo.width - (meanWidth / 2))) &&
                          (0 < face.y) && (face.y < ($scope.photo.height - (meanHeight / 2))))
                      {
                        $scope.photo.faces.push(face);
                        Face.save(face,
                                  function(data)
                                  {
                                    NameToPhotoGlue.mergeNewFacedata(data.names);
                                    face.id = data.face.id;
                                  },
                                  function(err)
                                  {
                                    $scope.removeFaceWithId(null);
                                    $window.alert($scope.xlate('unableToAddFace'));
                                  });
                      }
                      else
                      {
                        // TODO ...
                      }
                    }
                    $scope.noThumbnail = function(face)
                                         {
                                           return blank(face.thumbnail);
                                         }
                    $scope.removeFaceWithId = function(targetId)
                                              {
                                                var matchingIndex;
                                                angular.forEach($scope.photo.faces, function(f, index)
                                                {
                                                  if (f.id == targetId)
                                                  {
                                                    matchingIndex = index;
                                                  }
                                                });
                                                if (matchingIndex)
                                                {
                                                  // When we actually delete face (for real), we have to unbind
                                                  // the listener corresponding to the last array element, because
                                                  // the watch expressions are strings, for "face[i]", so when
                                                  // there is one less, the last listener goes away.
                                                  var lastListener = $scope.listeners.pop();
                                                  lastListener();  // Unbind

                                                  // Now remove the particular face
                                                  $scope.photo.faces.splice(matchingIndex, 1);
                                                }
                                              }
                    $scope.confirmFaceDeletion = function(face)
                                                  {
                                                    // We bypass the confirmation if it's both
                                                    // unnamed and manually created.
                                                    if ((face.manual && !face.namedFaceId) ||
                                                        confirm($scope.xlate('confirmDeleteFace')))
                                                    {
                                                      Face.delete({photo_id: face.photoId, id: face.id},
                                                                  function(data)
                                                                  {
                                                                    NameToPhotoGlue.mergeNewFacedata(data.names);
                                                                    if (data.face.destroyed) // true deletion
                                                                    {
                                                                      $scope.removeFaceWithId(face.id);
                                                                    }
                                                                    else
                                                                    {
                                                                      face.deleted = data.face.deleted; // TRUE
                                                                    }
                                                                  },
                                                                  function(err)
                                                                  {
                                                                    $window.alert($scope.xlate('unableToDeleteFace'));
                                                                  });
                                                      $scope.setHoverFace(null);
                                                    }
                                                  }
                    $scope.handleVisible = function()
                                           {
                                             return true;
                                           }
                    $scope.setHoverFace = function(face, delay) // no delay param -> immediate update
                                          {
                                            // If a face is specified, show it right away.
                                            // If it is not, start a timer and clear it a second later.
                                            if ($scope.hoverTimer) // If there is a timer running, clear it first
                                            {
                                              clearTimeout($scope.hoverTimer);
                                              $scope.hoverTimer = undefined;
                                            }
                                            if (!delay)
                                            {
                                              $scope.hoverFace = face;
                                            }
                                            else
                                            {
                                              $scope.hoverTimer = setTimeout(function()
                                                                             {
                                                                                $scope.hoverFace = face;
                                                                                $scope.$apply();
                                                                              },
                                                                              delay);
                                            }
                                          }
                    $scope.setHoverFace(null);

                    // If updateFace is called with one argument, then the
                    // server will be updated with all the various values stored
                    // in the object. When called with a second argument (that is
                    // a string), it attempt to create a new FaceName and assign
                    // it to this face.
                    $scope.updateFace = function(face, newName)
                    {
                        var data = {
                                      photoId: face.photoId,
                                      id: face.id,
                                      x: face.x,
                                      y: face.y,
                                      width: face.w,
                                      height: face.h
                                    };
                        if (typeof newName == 'string')
                        {
                          data.newName = newName;
                        }
                        else
                        {
                          data.namedFaceId = face.namedFaceId;
                        }
                        Face.update(data,
                                    function(data)
                                    {
                                      face.namedFaceId = data.face.namedFaceId;
                                      NameToPhotoGlue.mergeNewFacedata(data.names);
                                      face.displayName = NameToPhotoGlue.getPrivateName(face.namedFaceId);
                                      $scope.setHoverFace(null, 1200); // Leave a little time for them to see it.
                                    },
                                    function(err)
                                    {
                                      $window.alert($scope.xlate('errorApplyingChange'));
                                      $scope.setHoverFace(null);
                                    });
                    }
                    var faceResizeMoveOrNameChange = function(newValue, oldValue)
                    {
                      if (newValue) // It is undefined after a delete operation
                      {
                        // We only monitor x and y, as any move or resize operation
                        // must change at least one if not both of them.
                        if ((newValue.x != oldValue.x) || (newValue.y != oldValue.y))
                        {
                          debounce(newValue, 1500, $scope.updateFace)
                        }
                        else if (newValue.namedFaceId != oldValue.namedFaceId)
                        {
                          debounce(newValue, 100, $scope.updateFace)
                        }
                      }
                    }
                  }
                ]
  );

  app.controller('NamesController',
                 ['$scope', '$state', '$stateParams', '$http', '$window', 'Name', 'NameToPhotoGlue',
                  function($scope, $state, $stateParams, $http, $window, Name, NameToPhotoGlue)
                  {
                    $scope.Page.setTitle($scope.xlate('people'));
                    $scope.getRelatedPhotos = function(namedFaceId)
                                              {
                                                // We can fall in here any time there is an "id" param
                                                if ($state.current.name == 'names.show')
                                                {
                                                  $scope.name = $scope.names[namedFaceId];
                                                  $scope.Page.setTitle($scope.name.publicName);
                                                  Name.get({id: namedFaceId},
                                                           function(data)
                                                           {
                                                             $scope.faces = data.faces;
                                                           },
                                                           function(err)
                                                           {
                                                             $window.alert($scope.xlate('unableToGetRelatedPhotos'));
                                                           });
                                                }
                                              };
                    if (!NameToPhotoGlue.namesIndexInitialized())
                    {
                      $http.get("/api/v1/names.json?a_id=1")
                           .success(function(response)
                                    {
                                      NameToPhotoGlue.setNamesIndex(response);
                                      $scope.names = NameToPhotoGlue.getNamesIndex(); // After it's been processed
                                    }
                           );

                    }
                    else
                    {
                      $scope.names = NameToPhotoGlue.getNamesIndex();
                    }
                    $scope.nameNeedle = '';
                    $scope.hideNameEntry = function()
                                           {
                                             $('#name').hide();
                                           }
                    $scope.setSelectedName = function(name)
                                             {
                                               NameToPhotoGlue.setName(name);
                                               $scope.hideNameEntry();
                                             }
                    $scope.processKeydown = function(keyboardEvent)
                    {
                      if ((keyboardEvent.keyCode == 40) ||  // down
                          (keyboardEvent.keyCode == 38))
                      {
                        // We have to intercept these on the down, otherwise
                        // they perform field beginning/end cursor movements.
                        event.preventDefault();
                      }
                    }
                    $scope.processKeyup = function(keyboardEvent)
                    {
                      var key = keyboardEvent.which;
                      if (key == 27) // escape
                      {
                        $scope.hideNameEntry();
                      }
                      else if (key == 13) // return/enter
                      {
                        if (confirm('new name?'))
                        {
                          NameToPhotoGlue.applyNewName($scope.nameNeedle);
                          $scope.nameNeedle = '';
                        }
                        $scope.hideNameEntry();
                      }
                      keyboardEvent.stopPropagation()
                    }
                  }
                ]
  );

  app.controller('NameController',
                 ['$scope', '$state', '$stateParams', '$http', '$window', 'Name', 'NameToPhotoGlue',
                  function($scope, $state, $stateParams, $http, $window, Name, NameToPhotoGlue)
                  {
                    $scope.Page.setTitle($scope.xlate('people'));
                    $scope.getRelatedPhotos = function(namedFaceId)
                                              {
                                                // We can fall in here any time there is an "id" param
                                                if ($state.current.name == 'names.show')
                                                {
                                                  $scope.name = $scope.names[namedFaceId];
                                                  $scope.Page.setTitle($scope.name.publicName);
                                                  Name.get({id: namedFaceId},
                                                           function(data)
                                                           {
                                                             $scope.faces = data.faces;
                                                           },
                                                           function(err)
                                                           {
                                                             $window.alert($scope.xlate('unableToGetRelatedPhotos'));
                                                           });
                                                }
                                              };
                    if (!NameToPhotoGlue.namesIndexInitialized())
                    {
                      $http.get("/api/v1/names.json?a_id=1")
                           .success(function(response)
                                    {
                                      NameToPhotoGlue.setNamesIndex(response);
                                      $scope.names = NameToPhotoGlue.getNamesIndex(); // After it's been processed

                                      // This code is needed here for the times the single-name
                                      // route is visited directly.
                                      if ($stateParams.id)
                                      {
                                        $scope.getRelatedPhotos($stateParams.id)
                                      };

                                    }
                           );

                    }
                    if ($stateParams.id && $scope.names)
                    {
                      // and it's needed here for times when the data is already loaded.
                      $scope.getRelatedPhotos($stateParams.id)
                    }
                  }
                ]
  );

  app.filter('matchesNameNeedle',
              function ()
              {
                return function (name) {
                    return name.publicName.toUpperCase();
                };
              }
  );
  app.filter('object2Array',
              function()
              {
                return function(input) {
                  var out = [];
                  for (i in input){
                    out.push(input[i]);
                  }
                  return out;
                }
              }
  );

  