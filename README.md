# AWS glacier Upload Script
Scritpt to upload and download the file from aws glacier


The repository consist of the upload script and download script. 
You may be required to install below components for functioning of script.
* aws cli
* parallel
* jq
* ruby jem treehash

Upload Script

* Upload script performs a multipart upload
* Variables can be configured in the script according to the user 

Download Script

* Performs the retrieval of the uploaded file in the glacier
* The job fetch the status of the artifact in the glacier

Kindly note: The uploading of the artifact may take an approx. of 18hrs or more depending  upon the size of the file. The retrieval job needs to be completed to get downloaded which can be viewed by the status of the job
