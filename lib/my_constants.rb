
module MyConstants

# Value of status and permission bits for recipes
  Rcpstatus_rotation = 1
  Rcpstatus_favorites = 2
  Rcpstatus_interesting = 4
  Rcpstatus_misc = 8
  Rcpstatus_recent = 16 # For querying recently-touched recipes
  
  Rcpstatus_names = []
  Rcpstatus_names[Rcpstatus_rotation] = :recipe_status_high
  Rcpstatus_names[Rcpstatus_favorites] = :recipe_status_medium
  Rcpstatus_names[Rcpstatus_interesting] = :recipe_status_low
  Rcpstatus_names[Rcpstatus_misc] = :recipe_status_default

  Rcppermission_private = 1
  Rcppermission_friends = 2
  Rcppermission_circles = 4
  Rcppermission_public = 8

end
