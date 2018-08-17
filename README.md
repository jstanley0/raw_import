# raw_import
a quick and dirty script to find and import batches of files from a digital camera

## overview
this little tool helps me manage imports from several digital cameras. 
 * it keeps track of the timestamp of the last imported file on each memory card, so later imports only get new files
    * why don't I just delete files on import? I'll tell you why:
        * I prefer not to erase anything from the card until the photos have been backed up, RAWs to an external drive and JPEGs to the cloud
        * I'd rather avoid file system fragmentation and unnecessary writes by just formatting the card in-camera once its contents have been processed and backed up, rather than deleting its files one by one
 * it organizes imported files in YYYY/MM/DD folders.
    * _mostly_. I have some logic in there to avoid splitting photo sessions that span midnight.
 * it renames files for each camera to avoid clashes, so e.g. 6D2_4311.CR2 won't overwrite T3i_4311.CR2 if both happened to be taken on the same day (this actually _has_ happened to me once or twice over the years)

## usage
* edit the constants at the top of the script to specify your source/dest paths and file types to import
* optionally put a cam_prefix file in the root of your memory card containing the prefix to replace XXX_1234 with
* run ruby raw_import.rb
   * optionally specify an ISO date (YYYY-MM-DD) as the first argument to start importing as of this date
      * otherwise, it will resume from the last import, if there was one
      * and if there wasn't, it will import everything on the card
   
## note
this thing uses birthtime to organize files, not mtime - because sometimes I do quick edits in DPP on the memory card itself without importing, and I want the "date taken" rather than the "date edited"--without being compelled to extract this information from the metadata of three or four different file types (RAW, JPEG, MOV, etc.)

windows, bsd, and osx support birthtime. linux doesn't. sorry.
