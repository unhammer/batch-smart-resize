; https://github.com/per1234/batch-smart-resize

(define (script-fu-batch-smart-resize sourcePath destinationPath filenameModifier outputType outputQuality maxWidth maxHeight pad padColor . JPEGDCT)

  (define (load-and-resize filename)
    (let* ((image (car (gimp-file-load RUN-NONINTERACTIVE filename filename))))
      (gimp-image-undo-disable image)
      ;; crop to mask if one exists
      (if (not (= (car (gimp-layer-get-mask (car (gimp-image-get-active-layer image)))) -1)) (plug-in-autocrop RUN-NONINTERACTIVE image (car (gimp-layer-get-mask (car (gimp-image-get-active-layer image))))))
      ;; image manipulation
      (let*
          ( ;; get cropped source image dimensions
           (sourceWidth (car (gimp-image-width image)))
           (sourceHeight (car (gimp-image-height image)))
           ;; don't resize image to larger than original dimensions
           (outputMaxWidth (if (< sourceWidth maxWidth) sourceWidth maxWidth))
           (outputMaxHeight (if (< sourceHeight maxHeight) sourceHeight maxHeight))

           (outputWidth (if (< (/ sourceWidth sourceHeight) (/ outputMaxWidth outputMaxHeight)) (* (/ outputMaxHeight sourceHeight) sourceWidth) outputMaxWidth))
           (outputHeight (if (> (/ sourceWidth sourceHeight) (/ outputMaxWidth outputMaxHeight)) (* (/ outputMaxWidth sourceWidth) sourceHeight) outputMaxHeight)))
        (gimp-image-scale image outputWidth outputHeight)
        (if (= pad TRUE)
            (begin
              (gimp-image-resize image maxWidth maxHeight (/ (- maxWidth outputWidth) 2) (/ (- maxHeight outputHeight) 2))  ;resize canvas to to maximum dimensions and center the image
              ;; add background layer
              (let* ((backgroundLayer (car (gimp-layer-new image maxWidth maxHeight RGB-IMAGE "Background Layer" 100 NORMAL-MODE))))
                (let* ((backgroundColor (car (gimp-context-get-background)))) ;save the current background color so it can be reset after the padding is finished
                  (gimp-context-set-background padColor)  ;set background color to the padColor
                  (gimp-drawable-fill backgroundLayer 1)  ;Fill the background layer with the background color. I have to use 1 instead of FILL-BACKGROUND because GIMP 2.8 uses BACKGROUND-FILL.
                  (gimp-context-set-background backgroundColor)  ;reset the background color to the previous value
                  )
                (gimp-image-insert-layer image backgroundLayer 0 1)))))

      (gimp-image-flatten image)  ;flatten the layers
      image))

  (define (smart-resize fileCount sourceFiles messages)
    (let*
        ((filename (car sourceFiles))
         (outputFilenameNoExtension ;strip source extension(from http://stackoverflow.com/questions/1386293/how-to-parse-out-base-file-name-using-script-fu), add filename modifier and destination path
          (string-append
           destinationPath
           DIR-SEPARATOR
           (unbreakupstr
            (reverse
             (cdr
              (reverse
               (strbreakup
                (car
                 (reverse
                  (strbreakup filename DIR-SEPARATOR)))
                "."))))
            ".")
           filenameModifier))
         (extension (output-type-to-extension outputType))
         (outputFilename (string-append outputFilenameNoExtension extension))
         (messagesNext (if (file-exists? outputFilename)
                           (string-append messages
                                          "\nNot overwriting: "
                                          outputFilename)
                           (let ((image (load-and-resize filename)))
                             (save-as-type extension image outputFilename outputQuality JPEGDCT)
                             (gimp-image-delete image)
                             messages))))
      (if (= fileCount 1)        ;determine whether to continue the loop
          messagesNext
          (smart-resize (- fileCount 1)
                        (cdr sourceFiles)
                        messagesNext))))

  (define sourceFilesGlob (file-glob (string-append sourcePath DIR-SEPARATOR "*.*") 0))
  (if (pair? (car (cdr sourceFilesGlob)))  ;check for valid source folder(if this script is called from another script they may have passed an invalid path and it's much more helpful to return a meaningful error message)
      (let ((messages (smart-resize (car sourceFilesGlob) (car (cdr sourceFilesGlob)) "")))
        (if (equal? messages "")
            1                           ; why do we return 1?
            (gimp-message messages)))
    (error (string-append "Invalid Source Folder " sourcePath)))
)

(define (save-as-type extension image outputFilename outputQuality JPEGDCT)
  (cond
   ((equal? extension ".jpg")
                                        ;file-jpeg-save parameters
                                        ;The run mode(RUN-INTERACTIVE(0), RUN-NONINTERACTIVE(1))
                                        ;Input image
                                        ;Drawable to save
                                        ;filename
                                        ;raw-filename - this doesn't appear to do anything
                                        ;quality(0-1)
                                        ;smoothing(0-1)
                                        ;use optimized tables during huffman encoding(TRUE/FALSE)
                                        ;create progressive JPEG images(TRUE/FALSE)
                                        ;image comment(string)
                                        ;Sub-sampling type { 0, 1, 2, 3 } 0 == 4:2:0 (chroma quartered), 1 == 4:2:2 Horizontal (chroma halved), 2 == 4:4:4 (best quality), 3 == 4:2:2 Vertical (chroma halved)
                                        ;Force creation of a baseline JPEG (non-baseline JPEGs can't be read by all decoders) (TRUE/FALSE)
                                        ;Interval of restart markers (in MCU rows, 0 = no restart markers)
                                        ;DCT method to use {0, 1, 2} 0==integer, 1==fixed, 2==float
    (car (file-jpeg-save RUN-NONINTERACTIVE image (car (gimp-image-get-active-drawable image)) outputFilename outputFilename (/ outputQuality 100) 0 TRUE TRUE "" 2 TRUE 0 (if (null? JPEGDCT) 0 (car JPEGDCT)))))
   ((equal? extension ".png")
                                        ;file-png-save parameters
                                        ;The run mode { RUN-INTERACTIVE (0), RUN-NONINTERACTIVE (1) }
                                        ;Input image
                                        ;Drawable to save
                                        ;filename
                                        ;raw-filename - this doesn't appear to do anything
                                        ;Adam7 interlacing(Interlacing) Checking interlace allows an image on a web page to be progressively displayed as it is downloaded. Progressive image display is useful with slow connection speeds, because you can stop an image that is of no interest; interlace is of less use today with our faster connection speeds.
                                        ;deflate compression factor (0-9) Since compression is not lossy, the only reason to use a compression level less than 9, is if it takes too long to compress a file on a slow computer. Nothing to fear from decompression: it is as quick whatever the compression level.
                                        ;Write bKGD chunk(save background color) If your image has many transparency levels, the Internet browsers that recognize only two levels, will use the background color of your Toolbox instead. Internet Explorer up to version 6 did not use this information.
                                        ;Write gAMMA chunk(Save gamma) Gamma correction is the ability to correct for differences in how computers interpret color values. This saves gamma information in the PNG that reflects the current Gamma factor for your display. Viewers on other computers can then compensate to ensure that the image is not too dark or too bright.
                                        ;Write oFFs chunk(Save layer offset) PNG supports an offset value called the “oFFs chunk”, which provides position data. Unfortunately, PNG offset support in GIMP is broken, or at least is not compatible with other applications, and has been for a long time. Do not enable offsets, let GIMP flatten the layers before saving, and you will have no problems.
                                        ;Write pHYS chunk(Save Resolution) Save the image resolution, in ppi (pixels per inch). Are the pHYS and tIME parameters swapped in DB Browser?(from http://beefchunk.com/documentation/lang/gimp/GIMP-Scripts-Fu.html)
                                        ;Write tIME chunk(Save Creation Time) Date the file was saved.
    (file-png-save RUN-NONINTERACTIVE image (car (gimp-image-get-active-drawable image)) outputFilename outputFilename FALSE 9 TRUE FALSE FALSE TRUE TRUE))
   (else
    (begin
      (gimp-image-convert-indexed image 1 0 256 TRUE TRUE "")
                                        ;file-gif-save parameters
                                        ;The run mode(RUN-INTERACTIVE(0), RUN-NONINTERACTIVE(1))
                                        ;Input image
                                        ;Drawable to save
                                        ;filename
                                        ;raw-filename - this doesn't appear to do anything
                                        ;Try to save as interlaced(TRUE/FALSE?)
                                        ;(animated gif) loop infinitely(TRUE/FALSE?)
                                        ;(animated gif) Default delay between frames in milliseconds
                                        ;(animated gif) Default disposal type (0=`don't care`, 1=combine, 2=replace)
      (file-gif-save RUN-NONINTERACTIVE image (car (gimp-image-get-active-drawable image)) outputFilename outputFilename FALSE FALSE 0 0)))))

(define (output-type-to-extension outputType)
  (cond
   ((= outputType 0) ".jpg")
   ((= outputType 1) ".png")
   (else ".gif")))

;dialog
(script-fu-register
  "script-fu-batch-smart-resize"  ;function name
  "Resize all files in a folder"  ;menu label
  "Crop to layer mask, resize within maximum dimensions, and pad to max dimensions(optional)"  ;description
  "per1234"  ;author
  ""  ;copyright notice
  "2015-10-02"  ;date created
  ""  ;image type
  SF-DIRNAME "Source Folder" ""  ;sourcePath
  SF-DIRNAME "Destination Folder" ""  ;destinationPath
  SF-STRING "Output Filename Modifier (appended)" ""  ;filenameModifier
  SF-OPTION "Output Type" '("JPEG" "PNG" "GIF")       ;outputType
  SF-VALUE "Output Quality(JPEG only) 0-100" "90"  ;outputQuality
  SF-VALUE "Max Width" "1600"                      ;maxWidth
  SF-VALUE "Max Height" "1600"                     ;maxHeight
  SF-TOGGLE "Pad" FALSE  ;pad
  SF-COLOR "Padding Color" "white"  ;padColor
)

(script-fu-menu-register "script-fu-batch-smart-resize"
                         "<Image>/File")  ;menu location
