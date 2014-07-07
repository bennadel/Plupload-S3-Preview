
# Showing Client-Side Image Previews Using Plupload Before Uploading Images To Amazon S3

by [Ben Nadel][bennadel] (on [Google+][googleplus])

As a follow-up to my last exploration, [Using the BeforeUpload event to generate per-file Amazon S3 upload policies][plupload-s3-beforeupload],
I wanted to see if I could also generate a client-side preview of the selected images. Now, I've 
[tried working with Plupload previews before][plupload-preview], but never in the context of saving
the record before the upload (as I did in my previous exploration). As such, I wanted to look at 
how to best combine the power of the per-file Amazon S3 upload policy with the perceived 
performance boost of a client-side preview.


[bennadel]: http://www.bennadel.com
[googleplus]: https://plus.google.com/108976367067760160494?rel=author
[plupload]: http://plupload.com
[angularjs]: http://angularjs.org
[plupload-s3-beforeupload]: http://www.bennadel.com/blog/2653-using-beforeupload-to-generate-per-file-amazon-s3-upload-policies-using-plupload.htm
[plupload-preview]: http://www.bennadel.com/blog/2563-showing-plupload-image-previews-using-base64-encoded-data-urls.htm