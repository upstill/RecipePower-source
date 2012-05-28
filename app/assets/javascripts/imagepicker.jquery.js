// 
//  imagepicker.jquery.js
//  imagepicker
//  
//  Created by Tim Smith on 2012-01-05.
//  Copyright 2012 Tim Smith . All rights reserved.
// 
function imagePickerSelector(id) {
	return ".imagepicker"; // ".imagepicker[imgPickerId=" + id + "]"
}

(function($){  
    $.fn.imagepicker = function(options) {  
  		
        var defaults = {  
            placeholder: 'http://placehold.it/50x50',  
            data: '',  
            galleryUrl: '/imagepicker/gallery/' ,
            title: 'Select Image' 
          }, 
          params = ''; 
          settings = $.extend({}, defaults, options);  

		        this.each(function() {  
		            var $this = $(this),
			            randomnumber = Math.floor(Math.random()*10001),
		          		$layout  = $('.imagepicker'); 
						
						if(!$this.is("input")){
							
							console.log($this.prop('tagName') +'  is not a input field.');
							return ;
						}
						
		 				
						$this.hide();// hclasse our feild				
		  				
		  				// building our data
		  				$this.data('imgPickerId', randomnumber);
						$layout.data('imgPickerId',randomnumber);
						// $layout.data('open', false);
						$layout.data('allowed', $this.attr('rel'));
						
				});  
   				
   				
			// lets create our slclasse toggle functions for the UI
			$('.imagepicker .title').bind('click',function(event){
				
				// if(event.detail==1){//activate on first click only to avoid hiding again on double clicks
					params = getParams($(this));
					// now opening the picker 
					if(!params.open){
						// first we need to get our data
						// getData(params.id,params.parent,params.allowed);
			         	params.parent.data('open',true);// set closed
						//open em up
						$(params.imgPicker + ' .content' ).animate({opacity:'toggle'}, 500);
					
					}
					else{ 
						//close em down 							
						$(params.imgPicker + ' .content').animate({opacity:'toggle'}, 700, function() {
														    params.parent.data('open',false);// set closed
									  						});
						newtext = $('input#imgpicker').val() // Send resulting text to text input
						$('input#recipe_picurl').val(newtext)
						}
				//	}
						return false;
			});
			
			//  ========== 
			//  = Image Selector = 
			//  ========== 
			/*
				 clicking on the img will set the imge name to the field it was applied to
			*/
			$('.pickerImage img').live('click',function(){
				// get some data vars
					params = getParams($(this));
					sourceimg = $(this).attr('alt');
					// remove class
					$('.selected').removeClass('selected');
					// add selected class
					$(this).addClass('selected');
					// set our field value
					// $('input[imgPickerId=' + params.id + ']').val(sourceimg);
					$('input#recipe_picurl').val(sourceimg);
					//set preview image
					var imgSelector = params.imgPicker +' .preview img'
					$(imgSelector).css("visibility", "invisible");
					$(imgSelector).hide();
					$(imgSelector).attr('src',settings.galleryUrl + sourceimg);
					wdwFitImages();	
			});
          
          
          
         
          //  ========== 
          //  = Get Data = 
          //  ==========
          /*
               this requires  a url to passed to it.
               it will append li img to the imagepicker "modal"
				NB: No longer used because we pre-load the image selections
          */ 
          function getData(id,parent,allowed){
          	// getting json data
          	 $.getJSON(settings.data,function(image){
          	 		// looping each item
          	 		
				   $.each(image,function(i,item) {	
				   		
				   		if(validImg(item,allowed)){	   	
					   		// building  string 
							imgstring = "<li class=\"pickerImage\"><img src=\""+ settings.galleryUrl + item + "\" alt=\"" + item + "\"/></li>"+"\n";
							ipSelector = imagePickerSelector(id)
							$(ipSelector + " ul").append(imgstring);
							// $(".imagepicker ul").append(imgstring);
						}
						});//end each
         	});//end getJson
         	parent.data('open',true);// set closed
          }// end getData
          
          
          //  ========== 
          //  = Get Params = 
          //  ========== 
          // requires  $(this)
          // returns some data that depends on  $this data
          function getParams(x){
          				// getting values from this 
          				var $parent = $(x).parents('.imagepicker');
   						var id = $parent.data('imgPickerId');
   						var $imgPicker = imagePickerSelector(id); // [imgPickerId=' + id + ']';
   						var open = $parent.data('open');
   						var allowed = $parent.data('allowed');
          			// createing our object
	          			params = new Object()
	          				params.parent 	= $parent;
	          				params.id 		= id;
	          				params.imgPicker = $imgPicker;
	          				params.open = open;
	          				params.allowed = allowed;
	          				
  				return params // return the object		
          }
          
          //  ========== 
          //  = validImg = 
          //  ========== 
          /*
               lets make sure that the images are of the correct type.
          */
          function validImg(imgstring,allowed){
          	var bvalid = true;
			
          		if(allowed){
          				var imgobj = allowed.split(',');// our allowed image types
          				var img    = imgstring.split('.');// breaking the image string up
							img = img.reverse(); // reverse the array 
							img = img[0];// get the first item of the reversed array. ( i theroy we should ALWAYS get the file type )
						
          				if(jQuery.inArray(img, imgobj) < 0 ){
          					bvalid = false;// if the image isnt in the array dont show it.
          				}	
          		}
			return bvalid;	
          }
     
          
          // returns the jQuery object to allow for chainability.  
          return this;  
    }  
})(jQuery); 


(function($){
    var _dataFn = $.fn.data;
    $.fn.data = function(key, val){
        if (typeof val !== 'undefined'){ 
            $.expr.attrHandle[key] = function(elem){
                return $(elem).attr(key) || $(elem).data(key);
            };
        }
        return _dataFn.apply(this, arguments);
    };
})(jQuery);
