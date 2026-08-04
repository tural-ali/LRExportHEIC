return {
  sectionsForTopOfDialog = function( viewFactory, propertyTable )
    return {
      {
        title = 'Export HEIC plugin',
        viewFactory:column {
          viewFactory:static_text {
            title = 'This plugin allows exporting files as HEIC on macOS.'
          },
          viewFactory:spacer { height = 12 },
          viewFactory:static_text {
            title = 'Originally created by Manu Wallner (GitHub: @milch). Version 2 maintained by Tural Aliyev.'
          },
        }
      }
    }
  end
}
