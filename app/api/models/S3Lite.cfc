component
	output = false
	hint = "I provide minor access to the Amazon Simple Storage Service (S3) for this demo."
	{

	/**
	* I return the initialized component. To keep the API easy for this demo, this 
	* instance is locked down to a single Amazon S3 bucket.
	* 
	* @newBucket I am the amazon S3 bucket name.
	* @newAccessID I am the amazon account access ID.
	* @newSecretKey I am the amazon account secret key.
	* @output false
	*/
	public any function init(
		required string newBucket,
		required string newAccessID,
		required string newSecretKey
		) {

		// Store the bucket and authentication values.
		bucket = newBucket;
		accessID = newAccessID;
		secretKey = newSecretKey;

		// Set the location of the Amazon S3 domain. This will be added to our resources.
		amazonS3Domain = "https://s3.amazonaws.com";

		// Set the location of the Amazon S3 domain for use in pre-signed URLs.
		preSignedAmazonS3Domain = "https://s3.amazonaws.com";

		// Create an instance of the MAC class for reference; we have to call "static"
		// methods on it when generating the signatures.
		macClass = createObject( "java", "javax.crypto.Mac" );

		// Keep the local version of epoch so that we can easily create pre-signed URLs 
		// with expiration (using date-diff in seconds).
		localEpoch = dateConvert( "utc2local", "1970/01/01" );

		// I make the references to the line-return character easier to ready.
		lineReturn = chr( 10 );

		return( this );

	}


	// ---
	// PUBLIC METHODS.
	// ---


	/**
	* I generate the components needed to POST files directly to Amazon S3 using a pre-
	* authenticated request. Each request needs a policy, that defines the data that S3
	* should expect; and, a signature that authenticates the policy. 
	* 
	* @expiresAt I am the date after which the policy is no longer valid.
	* @conditions I am the collection of conditions to append to the policy.
	* @output false 
	*/
	public struct function getFormPostSettings(
		required date expiresAt,
		required array conditions
		) {

		// Create our base policy - this will be locked down to the current bucket.
		var policy = {
			"expiration" = (
				dateFormat( expiresAt, "yyyy-mm-dd" ) & "T" &
				timeFormat( expiresAt, "HH:mm:ss" ) & "Z"
			),
			"conditions" = [
				{
					"bucket" = bucket
				}
			]
		};

		// Append each user-provided condition.
		for ( var condition in conditions ) {

			arrayAppend( policy.conditions, condition );

		}

		var serializedPolicy = serializeJson( policy );

		// If the user povided a "success_action_status" condition, then it's likely 
		// that ColdFusion will mangle the value during JSON serialization. This value
		// needs to be a string - not a number. Try to convert it back to a string after
		// serialization by adding double-quotes around it.
		serializedPolicy = reReplace( 
			serializedPolicy, 
			"(""success_action_status"":)(\d+)(\.0)?", 
			"\1""\2""", 
			"one"
		);

		// Remove up the line breaks.
		serializedPolicy = reReplace( serializedPolicy, "[\r\n]+", "", "all" );

		// Encode the policy as Base64 so that it doesn't mess up the form post data 
		// at all.
		var encodedPolicy = binaryEncode(
			charsetDecode( serializedPolicy, "utf-8" ) ,
			"base64"
		);

		// To make sure that no one tampers with the policy we need to create a hashed
		// version of it for our signature (in base64 encoding).
		var hashedPolicy = getHmacSha1( secretKey, encodedPolicy );

		// The result of this will provdie the calling context with the target URL of the
		// post along with the both the policy and the signature for that policy.
		var settings = {
			url = "http://#bucket#.s3.amazonaws.com",
			policy = encodedPolicy,
			signature = hashedPolicy
		};

		return( settings );

	}


	/**
	* I generate a pre-signed / pre-authenticated URL for the given resource.
	* 
	* @key I am the S3 object key (does not start with "/").
	* @expiresAt I am the expiration date of the URL (assumed to be UTC).
	* @output false
	*/
	public string function getPreSignedUrl(
		required string key,
		required date expiresAt
		) {

		var resource = ( "/" & bucket & "/" & urlEncodeKey( key ) );

		var expirationInSeconds = dateDiff( "s", localEpoch, expiresAt );

		var signature = getPreSignedRequestSignature(
			method = "GET",
			expires = expirationInSeconds,
			resource = resource
		);

		var urlEncodedSignature = urlEncodedFormat( signature );

		return( "#preSignedAmazonS3Domain##resource#?AWSAccessKeyId=#accessID#&Expires=#expirationInSeconds#&Signature=#urlEncodedSignature#" );

	}


	// ---
	// PRIVATE METHODS.
	// ---


	/**
	* I return the Hmac-Sha1 hashing of the given input, using the given key. The hash
	* value is returned in Base64 (since this is what Amazon S3 is expecting).
	* 
	* @key I am the secret key used to hash the input.
	* @input I am the message being hashsed.
	* @output false
	*/
	private string function getHmacSha1(
		required string key,
		required string input
		) {

		var secretkeySpec = createObject( "java", "javax.crypto.spec.SecretKeySpec" ).init(
			toBinary( toBase64( key ) ),
			javaCast( "string", "HmacSHA1" )
		);

		var mac = macClass.getInstance( javaCast( "string", "HmacSHA1" ) );

		mac.init( secretkeySpec );

		var hashedBytes = mac.doFinal( charsetDecode( input, "utf-8" ) );

		return( binaryEncode( hashedBytes, "base64" ) );

	}


	/**
	* I generate the signature for use in pre-signed url requests (in base64).
	* 
	* @method I am the HTTP method being used.
	* @expires I am the expiration date for the URL (in seconds since Epoch).
	* @resource I am the S3 object key being accessed.
	* @md5Hash I am the optional content hash used to validate the request.
	* @contentType I am the optional content-type used in the request.
	* @output false
	*/
	private string function getPreSignedRequestSignature(
		required string method,
		required numeric expires,
		required string resource,
		string md5Hash = "",
		string contentType = ""
		) {

		var partsToSign = [];

		arrayAppend( partsToSign, ucase( method ) );
		arrayAppend( partsToSign, md5Hash );
		arrayAppend( partsToSign, contentType );
		arrayAppend( partsToSign, expires );
		// NOTE: Options Amazon headers would go here.
		arrayAppend( partsToSign, resource );

		var stringToSign = arrayToList( partsToSign, lineReturn );

		return( getHmacSha1( secretKey, stringToSign ) );

	}


	/**
	* I encode the object key for us in the url. 
	* 
	* @key I am the object key.
	* @output false
	*/
	private string function urlEncodeKey( required string key ) {

		key = urlEncodedFormat( key );

		// urlEncodedFormat() is a bit too aggressive when it comes to URL escaping  
		// characters. We have to put some back in.
		key = replace( key, "%20", "+", "all" );
		key = replace( key, "%2D", "-", "all" );
		key = replace( key, "%2E", ".", "all" );
		key = replace( key, "%2F", "/", "all" );
		key = replace( key, "%5F", "_", "all" );
		key = replace( key, "%7E", "~", "all" );

		return( key );

	}

}