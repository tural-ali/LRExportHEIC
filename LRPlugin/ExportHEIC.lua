local LrBinding = import 'LrBinding'
local LrApplication = import 'LrApplication'
local LrFileUtils = import 'LrFileUtils'
local LrLogger = import 'LrLogger'
local LrPathUtils = import 'LrPathUtils'
local LrTasks = import 'LrTasks'
local LrView = import 'LrView'

local logger = LrLogger('ExportHEIC')
logger:enable('print')

function formatPercentage(num, fromModel)
  return tostring(math.floor(num)) .. ' %'
end

local function shellQuote(value)
  return "'" .. string.gsub(tostring(value), "'", "'\\''") .. "'"
end

local function lightroomVersion()
  local success, version = pcall(function()
    local v = LrApplication.versionTable()
    return table.concat({ v.major or 0, v.minor or 0, v.revision or 0 }, '.')
  end)
  return success and version or 'unknown'
end

local function deleteTemporaryFilesAfterCompletion(paths)
  if #paths == 0 then return end

  LrTasks.startAsyncTask(function()
    -- Lightroom can inspect filter renditions while the post-processing
    -- callback is unwinding. Deleting them synchronously after
    -- renditionIsDone() can therefore turn a successful export into a false
    -- "failed to render" result.
    LrTasks.sleep(2)

    for _, path in ipairs(paths) do
      local callSucceeded, deleted, deleteError = pcall(LrFileUtils.delete, path)
      if not callSucceeded then
        logger:warn('Could not delete temporary TIFF: ' .. tostring(deleted))
      elseif deleted == false then
        logger:warn('Could not delete temporary TIFF: ' .. tostring(deleteError))
      else
        logger:info('Deleted temporary TIFF: ' .. path)
      end
    end
  end)
end

return {
  exportPresetFields = {
    { key = 'HEICQuality', default = 75 },
    { key = 'HEICUseSizeLimit', default = false },
    { key = 'HEICSizeLimit', default = 3000 },
    { key = 'HEICMinQuality', default = 10 },
    { key = 'HEICMaxQuality', default = 90 },
    { key = 'HEICColorSpace', default = 'SRGB' },
    { key = 'HEICBitDepth', default = 10 },
    { key = 'HEICImportPhotos', default = false },
    { key = 'HEICDeleteTemporary', default = true },
    { key = 'HEICParallelism', default = 4 },
    { key = 'HEICLogLevel', default = 'info' },
  },
  hideSections = { 'video', 'fileSettings' },
  -- sectionsForTopOfDialog = function( viewFactory, propertyTable )
  sectionForFilterInDialog = function( viewFactory, propertyTable )
    local f = viewFactory
    local bind = LrView.bind
    local negbind = LrBinding.negativeOfKey

    return {
      title = 'HEIC Settings',

      f:row {  -- root row
        margin_top = 8,
        margin_bottom = 8,
        spacing = 18,

        f:column {  -- left-column
          spacing = 12,

          f:row {  -- control 1: quality
            f:static_text {
              title = 'Quality:', enabled = negbind 'HEICUseSizeLimit',
              width_in_chars = 8, alignment = 'right',
            },
            f:spacer { width = 2 },
            f:slider {
              value = bind 'HEICQuality',
              enabled = negbind 'HEICUseSizeLimit',
              min = 0, max = 100, integral = true,
            },
            f:static_text {
              title = bind({ key = 'HEICQuality', transform = formatPercentage }),
              enabled = negbind 'HEICUseSizeLimit',
            },
          },  -- control 1: quality

          f:row {  -- control 2: color space
            f:static_text { width_in_chars = 8, alignment = 'right', title = 'Color Space:' },
            f:spacer { width = 2 },
            f:popup_menu {
              width_in_chars = 8,
              items = {
                { title = 'sRGB', value = 'SRGB' },
                { title = 'Display P3', value = 'DisplayP3' },
                { title = 'AdobeRGB', value = 'AdobeRGB1998' },
              },
              value = bind 'HEICColorSpace'
            },
          },  -- control 2: color space

          f:row {  -- control 3: bit depth
            f:static_text { width_in_chars = 8, alignment = 'right', title = 'Bit Depth:' },
            f:spacer { width = 2 },
            f:radio_button { value = bind 'HEICBitDepth', title = '8', checked_value = 8 },
            f:radio_button { value = bind 'HEICBitDepth', title = '10', checked_value = 10 },
          },  -- control 3: bit depth

          f:row {
            f:checkbox { value = bind 'HEICImportPhotos', title = 'Import into Apple Photos' },
          },

          f:row {
            f:checkbox { value = bind 'HEICDeleteTemporary', title = 'Delete temporary TIFFs' },
          },

        },  -- left-column

        f:column {  -- right column
          spacing = 12,

          f:row {  -- control 1: file size
            f:checkbox { value = bind 'HEICUseSizeLimit', title = 'Limit File Size To:' },
            f:edit_field {
              value = bind 'HEICSizeLimit',
              enabled = bind 'HEICUseSizeLimit',
              increment = 100, large_increment = 1000,
              min = 1, max = 1000000,
              width_in_digits = 7,
            },
            f:static_text { title = 'K' },
          },  -- control 1: file size

          f:view {  -- control 2: min quality
            visible = bind 'HEICUseSizeLimit',
            place = 'horizontal',
            f:static_text { width_in_chars = 9, title = 'Minimal Quality:' },
            f:slider {
              value = bind 'HEICMinQuality',
              min = 0, max = 100, integral = true,
            },
            f:static_text {
              title = bind({ key = 'HEICMinQuality', transform = formatPercentage })
            },
          },

          f:row {
            f:static_text { width_in_chars = 9, title = 'Parallel jobs:' },
            f:edit_field {
              value = bind 'HEICParallelism',
              min = 1, max = 16, integral = true, width_in_digits = 2,
            },
          },

          f:row {
            f:static_text { width_in_chars = 9, title = 'Log level:' },
            f:popup_menu {
              width_in_chars = 8,
              items = {
                { title = 'Errors', value = 'error' },
                { title = 'Info', value = 'info' },
                { title = 'Debug', value = 'debug' },
              },
              value = bind 'HEICLogLevel',
            },
          },

          f:view {  -- control 3: max quality
            visible = bind 'HEICUseSizeLimit',
            place = 'horizontal',
            f:static_text { width_in_chars = 9, title = 'Maximal Quality:' },
            f:slider {
              value = bind 'HEICMaxQuality',
              min = 0, max = 100, integral = true,
            },
            f:static_text {
              title = bind({ key = 'HEICMaxQuality', transform = formatPercentage })
            },
          },
        },  -- right column

      }  -- root row
    }
  end,
  postProcessRenderedPhotos = function(functionContext, filterContext)
    local p = filterContext.propertyTable

    local renditionOptions = {
      filterSettings = function( renditionToSatisfy, exportSettings )
        exportSettings.LR_format = 'TIFF'
        if p.HEICBitDepth > 8 then
          exportSettings.LR_export_bitDepth = 16
        else
          exportSettings.LR_export_bitDepth = 8
        end

        if p.HEICColorSpace == "SRGB" then
          exportSettings.LR_export_colorSpace = "sRGB"
        elseif p.HEICColorSpace == "AdobeRGB1998" then
          exportSettings.LR_export_colorSpace = "AdobeRGB"
        elseif p.HEICColorSpace == "DisplayP3" then
          exportSettings.LR_export_colorSpace = "DisplayP3"
        end
        return os.tmpname()
      end,
    }

    local converterPath = LrPathUtils.child(_PLUGIN.path, 'LRExportHEIC')
    local cmd = shellQuote(converterPath)
    if p.HEICUseSizeLimit then
      cmd = (cmd .. ' --size-limit ' .. (p.HEICSizeLimit * 1000)
             .. ' --min-quality ' .. (p.HEICMinQuality / 100)
             .. ' --max-quality ' .. (p.HEICMaxQuality / 100))
    else
      cmd = cmd .. ' --quality ' .. (p.HEICQuality / 100)
    end

    cmd = cmd .. ' --bit-depth ' .. p.HEICBitDepth
      .. ' --color-space ' .. shellQuote(p.HEICColorSpace)
      .. ' --log-level ' .. shellQuote(p.HEICLogLevel)
      .. ' --lightroom-version ' .. shellQuote(lightroomVersion())
    if p.HEICImportPhotos then
      cmd = cmd .. ' --photos-import'
    end

    logger:info('Starting rendering of TIFF originals')
    local jobs = {}
    for sourceRendition, renditionToSatisfy in  filterContext:renditions(renditionOptions) do
      logger:info('Processing rendition')
      local success, pathOrMessage = sourceRendition:waitForRender()
      if success then
        table.insert(jobs, {
          inputPath = pathOrMessage,
          destinationPath = renditionToSatisfy.destinationPath,
          rendition = renditionToSatisfy,
        })
      else
        logger:info('Source rendition did not finish rendering: ' .. pathOrMessage)
        renditionToSatisfy:renditionIsDone(false, pathOrMessage)
      end
    end


    local nextJob = 1
    local completedWorkers = 0
    local workerCount = math.min(math.max(1, p.HEICParallelism), #jobs)
    local function runWorker()
      while true do
        local index = nextJob
        nextJob = nextJob + 1
        local job = jobs[index]
        if not job then break end

        local actualCmd = cmd .. ' --input-file ' .. shellQuote(job.inputPath)
          .. ' ' .. shellQuote(job.destinationPath)
        logger:info('Converting: ' .. job.inputPath)
        job.status = LrTasks.execute(actualCmd)
      end
      completedWorkers = completedWorkers + 1
    end

    for _ = 1, workerCount do
      LrTasks.startAsyncTask(runWorker)
    end
    while completedWorkers < workerCount do
      LrTasks.sleep(0.05)
    end

    local temporaryFilesToDelete = {}
    for _, job in ipairs(jobs) do
      if job.status == 0 then
        job.rendition:renditionIsDone(true, 'Success')
        if p.HEICDeleteTemporary then
          table.insert(temporaryFilesToDelete, job.inputPath)
        end
      else
        logger:error('Conversion failed with status ' .. tostring(job.status))
        job.rendition:renditionIsDone(false, 'HEIC conversion failed. See ~/Library/Logs/LRExportHEIC/.')
      end
    end
    deleteTemporaryFilesAfterCompletion(temporaryFilesToDelete)
  end,
  -- processRenderedPhotos = function(functionContext, exportContext)
  -- end
}
