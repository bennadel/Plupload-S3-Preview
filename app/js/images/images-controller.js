
app.controller(
	"ImagesController",	
	function( $scope, imagesService ) {

		// I hold the uploaded images.
		$scope.images = [];

		// I handle the event when the selected image file is available locally for 
		// preview - this is before it is actually saved to our server (or to S3).
		$scope.$on( "imageAvailable", handleImageAvailable );

		// I handle the event in which the selected file failed to save to our server.
		// This gives us an opportunity to remove any rendered preview.
		$scope.$on( "imageUnavailable", handleImageUnavailable );

		// I handle upload events for the images (ie, the response from the server after
		// the image has been uploaded to S3).
		$scope.$on( "imageUploaded", handleImageUploaded );

		// Load the remote data from the server.
		loadRemoteData();


		// ---
		// PUBLIC METHODS.
		// ---


		// I delete the given image.
		$scope.deleteImage = function( image ) {

			// Immediately remove the image locally - we'll assume best case scendario
			// with server-side communication; there's no reason that this should throw
			// an error on a normal usage basis.
			removeImage( image.id );

			// Delete from remote data store.
			imagesService.deleteImage( image.id ).then(
				function deleteImageResolve( response ) {

					console.info( "Image deleted scucessfully." );

					// Clean up object references for garbage collection.
					image = null;

				},
				function deleteImageReject( error ) {

					alert( "Oops! " + error.message );

				}
			);

		};


		// ---
		// PRIVATE METHODS.
		// ---


		// I apply the remote data to the local scope.
		function applyRemoteData( images ) {

			$scope.images = augmentImages( images );

		}


		// I prepare an image for use in the local scope.
		function augmentImage( image ) {

			// Add the properties that we will need when showing a client-side preview
			// of the selected file. 
			image.isPreview = false;
			image.previewImageID = 0;

			return( image );

		}


		// I prepare the images for use in the local scope.
		function augmentImages( images ) {

			for ( var i = 0, length = images.length ; i < length ; i++ ) {

				augmentImage( images[ i ] );

			}

			return( images );

		}


		// I handle the event in which the locally-selected file can be previewed as a
		// data-url. At this point, we neither have a server-side record nor an S3 
		// uplaod; but, we should have enough data to fake it 'til we make it.
		function handleImageAvailable( event, imageProxy ) {

			imageProxy.load( 150, 150 ).then(
				function loadResolve( preview ) {

					// Since the load of the data-uri and the client-size resizing take 
					// place asynchronously, there is a small chance that the real image
					// has actually loaded before the local preview has become available.
					// In such a case, we obviously want to ignore this and just let the
					// true image stay on the page.
					if ( imagePreviewNoLongerRelevant( preview.id ) ) {

						return;

					}

					// Build out our image preview scaffolding. This is are our "fake"
					// image record that we are rendering locally - here, we can translate
					// our Plupload data points to mimic image data points.
					var image = augmentImage({
						id: preview.id,
						clientFile: preview.name,
						imageUrl: preview.dataUrl
					});

					// Make sure we can identify this image as a "preview" later, once
					// the true image has been loaded.
					image.isPreview = true;
					image.previewImageID = preview.id;

					$scope.images.push( image );

					// Clean up object references for garbage collection.
					event = imageProxy = preview = image = null;

				}
			);

		}


		// I handle the event in which a previewed-image record failed to save to our
		// server. In such a case, we need to remove it from the local collection.
		function handleImageUnavailable( event, previewImageID ) {

			removeImage( previewImageID );

		}


		// I handle the image upload response from the server. This happens when the 
		// image record has been saved to our server and the image binary has been 
		// uploaded to the Amazon S3 bucket.
		// --
		// NOTE: The previewImageID is the plupload ID that was associated with the 
		// file selection. This is what we used as the image ID when we generated the 
		// image preview object.
		function handleImageUploaded( event, image, previewImageID ) {

			image = augmentImage( image );

			// Copy over the ID of the image proxy. We need to do this in case the 
			// asynchronous nature of the loading / thumbnailing / cropping has made a 
			// not-yet-loaded proxy image no longer relevant.
			image.previewImageID = previewImageID;

			// In the loop below, we're going to maintain use of the local image preview.
			// However, we want to load the true image in the bcakground so that the 
			// browser cache will be populated when the view is refreshed.
			preloadBrowserCache( image, image.imageUrl );

			// Look to see if we have a local preview of the image already being rendered
			// in our list. If we do, then we want to swap the proxy image out with the
			// true image (keeping it in the same place in the list).
			for ( var i = 0, length = $scope.images.length ; i < length ; i++ ) {

				if ( $scope.images[ i ].id === previewImageID ) {

					// Copy over the "preview" image URL into the true image. We're doing
					// this so we don't create a flickering affect as the remote image is
					// renderd. We also don't incure an HTTP request during the rest of 
					// the queue processing (less the browser pre-caching above).
					image.imageUrl = $scope.images[ i ].imageUrl;

					// Swap images.
					return( $scope.images[ i ] = image );

				}

			}

			// If we made it this far, we don't have a local preview (image proxy). As
			// such, we can just add this saved image to the local collection.
			$scope.images.push( image );

		}


		// I determine if the "real" image associated with the given preview ID has 
		// already been saved to the server and loaded locally.
		function imagePreviewNoLongerRelevant( previewImageID ) {

			// If any of the rendered images have a matching preview ID, then it means 
			// we have a saved-image in the list; as such, we don't need the preview.
			for ( var i = 0, length = $scope.images.length ; i < length ; i++ ) {

				if ( $scope.images[ i ].previewImageID === previewImageID ) {

					return( true );

				}

			}

			return( false );

		}


		// I get the remote data from the server.
		function loadRemoteData() {

			imagesService.getAllImages().then(
				function getAllImagesSuccess( response ) {

					applyRemoteData( response );

				},
				function getAllImagesError( error ) {

					console.warn( "Could not load remote data." );
					console.error( "Oops! " + error.message );

				}
			);

		}


		// I preload the given image url so that it will be pre-populated in the browser
		// cache so that it will be available when the view is refreshed.
		function preloadBrowserCache( image, imageUrl ) {

			// NOTE: Using a slight delay to not hog the current HTTP request pool.
			setTimeout(
				function preloadBrowserCacheTimeout() {

					( new Image() ).src = imageUrl;

					// Clean up object references for garbage collection.
					image = imageUrl = null;

				},
				5000
			);

		}


		// I delete the image with the given ID from the local collection.
		function removeImage( id ) {

			for ( var i = 0, length = $scope.images.length ; i < length ; i++ ) {

				if ( $scope.images[ i ].id === id ) {

					return( $scope.images.splice( i, 1 ) );

				}

			}

		}

	}
);
