#
# Wire
# Copyright (C) 2016 Wire Swiss GmbH
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see http://www.gnu.org/licenses/.
#

window.z ?= {}
z.entity ?= {}

# Base message entity.
class z.entity.Message
  ###
  Sort messages by timestamp
  @return [Boolean] Is message of type system
  ###
  @sort_by_timestamp: (message_ets) ->
    message_ets.sort (m1, m2) -> m1.timestamp > m2.timestamp

  # Construct a new base message entity.
  constructor: (@id = '0', @super_type = '') ->
    @ephemeral_caption = ko.observable ''
    @ephemeral_duration = ko.observable 0
    @ephemeral_remaining = ko.observable 0
    @ephemeral_expires = ko.observable false
    @ephemeral_started = ko.observable '0'
    @ephemeral_status = ko.computed =>
      if @ephemeral_expires() is true
        return z.message.EphemeralStatusType.TIMED_OUT

      if _.isNumber @ephemeral_expires()
        return z.message.EphemeralStatusType.INACTIVE

      if _.isString @ephemeral_expires()
        if @ephemeral_expires() > Date.now()
          return z.message.EphemeralStatusType.ACTIVE
        else
          return z.message.EphemeralStatusType.TIMED_OUT

      return z.message.EphemeralStatusType.NONE

    @conversation_id = ''
    @from = ''
    @is_editing = ko.observable false
    @primary_key = undefined
    @status = ko.observable z.message.StatusType.UNSPECIFIED
    @type = ''
    @user = ko.observable new z.entity.User()
    @visible = ko.observable true
    @version = 1

    @timestamp = Date.now()
    @should_effect_conversation_timestamp = true

    # z.message.MessageCategory
    @category = undefined

    @display_timestamp_short = =>
      date = moment.unix @timestamp / 1000
      return date.local().format 'HH:mm'

    @sender_name = ko.pureComputed =>
      z.util.get_first_name @user()
    , @, deferEvaluation: true

    @accent_color = ko.pureComputed =>
      return "accent-color-#{@user().accent_id()}"

  ###
  Check if message contains an asset of type file.
  @return [Boolean] Message contains any file type asset
  ###
  has_asset: ->
    if @is_content()
      return true for asset_et in @assets() when asset_et.type is z.assets.AssetType.FILE
    return false

  ###
  Check if message contains a file asset.
  @return [Boolean] Message contains a file
  ###
  has_asset_file: ->
    if @is_content()
      return true for asset_et in @assets() when asset_et.is_file()
    return false

  ###
  Check if message contains any image asset.
  @return [Boolean] Message contains any image
  ###
  has_asset_image: ->
    if @is_content()
      return true for asset_et in @assets() when asset_et.is_image()
    return false

  ###
  Check if message contains a location asset.
  @return [Boolean] Message contains a location
  ###
  has_asset_location: ->
    if @is_content()
      return true for asset_et in @assets() when asset_et.is_location()
    return false

  ###
  Check if message contains a text asset.
  @return [Boolean] Message contains text
  ###
  has_asset_text: ->
    if @is_content()
      return true for asset_et in @assets() when asset_et.is_text()
    return false

  ###
  Check if message contains a nonce.
  @return [Boolean] Message contains a nonce
  ###
  has_nonce: ->
    return @super_type in [z.message.SuperType.CONTENT]

  ###
  Check if message is a call message.
  @return [Boolean] Is message of type call
  ###
  is_call: ->
    return @super_type is z.message.SuperType.CALL

  ###
  Check if message is a content message.
  @return [Boolean] Is message of type content
  ###
  is_content: ->
    return @super_type is z.message.SuperType.CONTENT

  ###
  Check if the message content can be downloaded
  @return [Boolean] Is message of type content
  ###
  is_downloadable: ->
    return @get_first_asset?().download?

  ###
  Check if message is a member message.
  @return [Boolean] Is message of type member
  ###
  is_member: ->
    return @super_type is z.message.SuperType.MEMBER

  ###
  Check if message is a ping message.
  @return [Boolean] Is message of type ping
  ###
  is_ping: ->
    return @super_type is z.message.SuperType.PING

  ###
  Check if message is a system message.
  @return [Boolean] Is message of type system
  ###
  is_system: ->
    return @super_type is z.message.SuperType.SYSTEM

  ###
  Check if message is a e2ee message.
  @return [Boolean] Is message of type system
  ###
  is_device: ->
    return @super_type is z.message.SuperType.DEVICE

  ###
  Check if message is a e2ee message.
  @return [Boolean] Is message of type system
  ###
  is_all_verified: ->
    return @super_type is z.message.SuperType.ALL_VERIFIED

  ###
  Check if message is a e2ee message.
  @return [Boolean] Is message of type system
  ###
  is_unable_to_decrypt: ->
    return @super_type is z.message.SuperType.UNABLE_TO_DECRYPT

  ###
  Check if message can be deleted.
  @return [Boolean]
  ###
  is_deletable: ->
    return true if @is_ping() or not @has_asset()
    return @get_first_asset().status() not in [z.assets.AssetTransferState.DOWNLOADING,
        z.assets.AssetTransferState.UPLOADING]

  ###
  Check if message can be edited.
  @return [Boolean]
  ###
  is_editable: ->
    return @has_asset_text() and @user().is_me and not @is_ephemeral()

  ###
  Check if message is ephemeral.
  @return [Boolean]
  ###
  is_ephemeral: ->
    return @ephemeral_expires() isnt false

  ###
  Check if ephemeral message is expired.
  @return [Boolean]
  ###
  is_expired: =>
    return @ephemeral_expires() is true

  ###
  Check if message can be reacted to.
  @return [Boolean]
  ###
  is_reactable: ->
    return @is_content() and @status() isnt z.message.StatusType.SENDING and not @is_ephemeral()

  # Start the ephemeral timer for the message.
  start_ephemeral_timer: =>
    return if @ephemeral_timeout_id

    if @ephemeral_status() is z.message.EphemeralStatusType.INACTIVE
      @ephemeral_expires new Date(Date.now() + @ephemeral_expires()).getTime().toString()
      @ephemeral_started new Date(Date.now()).getTime().toString()

    @ephemeral_remaining @ephemeral_expires() - Date.now()

    @ephemeral_interval_id = window.setInterval =>
      @ephemeral_remaining @ephemeral_expires() - Date.now()
      @ephemeral_caption z.util.format_time_remaining @ephemeral_remaining()
    , 250

    @ephemeral_timeout_id = window.setTimeout =>
      amplify.publish z.event.WebApp.CONVERSATION.EPHEMERAL_MESSAGE_TIMEOUT, @
      window.clearInterval @ephemeral_interval_id
    , @ephemeral_remaining()

  ###
  Update the status of a message.
  @param update_status [z.message.StatusType] New status of message
  ###
  update_status: (updated_status) ->
    if @status() >= z.message.StatusType.SENT
      if updated_status > @status()
        return @status updated_status
    else if @status() isnt updated_status
      return @status updated_status
    return false
