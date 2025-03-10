--
-- MARK: JSON FEED TYPES
--

--- @alias JsonFeedAuthor {name: string, url: string, avatar: string}
--- @alias JsonFeedItem {id: string, url: string, content_html: string, date_published: string, authors: JsonFeedAuthor[], language: string}

--
-- MARK: JSON FEED FUNCTIONS
--

--- Render the JSON feed items as an "array" (table).
--- @param records BskyFeedItem[] The Bluesky records to turn into a JSON Feed.
--- @param profileData (Profile) The profile of the user whose feed is being rendered.
--- @param renderItemText (function) A function which produces a string with HTML text for the feed item.
--- @return JsonFeedItem[] The items for the feed.
local function generateItems(records, profileData, renderItemText)
    local jfItems = {}
    -- Hint to EncodeJson that this should be serialized as an array, even if there's nothing in it.
    jfItems[0] = false
    for i = 1, #records do
        local item = records[i]
        local uri = Bsky.util.atUriToWebUri(item.post.uri)
        local itemText, itemAuthors = renderItemText(item, profileData, uri)
        local authors = {}
        for _, author in ipairs(itemAuthors) do
            local authorStr = author.handle
            if author.displayName and #author.displayName > 0 then
                authorStr =
                    string.format("%s @%s", author.displayName, author.handle)
            end
            table.insert(authors, {
                name = authorStr,
                url = Bsky.util.didToProfileHttpUri(author.did),
                avatar = author.avatar,
            })
        end
        local date_published = item.post.record.createdAt
        if
            item.reason
            and item.reason["$type"] == "app.bsky.feed.defs#reasonRepost"
        then
            date_published = item.reason.indexedAt
        end
        local jfItem = {
            id = uri,
            url = uri,
            content_html = itemText,
            date_published = date_published,
            authors = authors,
        }
        if item.post.record.langs and item.post.record.langs[0] then
            jfItem.language = item.post.record.langs[0]
        end
        table.insert(jfItems, jfItem)
    end
    return jfItems
end

--- Render the JSON Feed to a string.
--- @param records (table) The bluesky posts to render.
--- @param profileData (Profile) The profile of the user whose feed is being rendered.
--- @param renderItemText (function) A function which produces a string with HTML text for the feed item.
--- @return (string) A valid JSON instance containing JSON Feed data describing the feed.
local function render(records, profileData, renderItemText)
    local profileName = (#profileData.displayName > 0)
            and profileData.displayName
        or profileData.handle
    local title = profileName .. " (Bluesky)"
    local profileLink = Bsky.util.didToProfileHttpUri(profileData.did)
    local authorName = profileData.handle
    if #profileData.displayName > 0 then
        authorName =
            string.format("%s @%s", profileData.displayName, profileData.handle)
    end
    local feed = {
        version = "https://jsonfeed.org/version/1.1",
        title = title,
        home_page_url = profileLink,
        feed_url = GetUrl(),
        description = "Posts on Bluesky by " .. profileName,
        icon = profileData.avatar,
        authors = {
            {
                name = authorName,
                url = profileLink,
                avatar = profileData.avatar,
            },
        },
        items = generateItems(records, profileData, renderItemText),
    }
    return assert(EncodeJson(feed))
end

return { render = render }
