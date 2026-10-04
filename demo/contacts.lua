-- Contacts shared by the Containment list and the Text inputs form.
local overlay = require("m3.overlay")

local M = {}

local CONTACTS = {
    { name = "Ada Lovelace", detail = "Analytical Engine notes" },
    { name = "Alan Turing", detail = "Computable numbers" },
    { name = "Barbara Liskov", detail = "Substitution principle" },
    { name = "Claude Shannon", detail = "Information theory" },
    { name = "Donald Knuth", detail = "The Art of Computer Programming" },
    { name = "Edsger Dijkstra", detail = "Shortest paths" },
    { name = "Frances Allen", detail = "Compiler optimisation" },
    { name = "Grace Hopper", detail = "COBOL and the first compiler" },
    { name = "John McCarthy", detail = "Lisp" },
    { name = "Katherine Johnson", detail = "Orbital mechanics" },
    { name = "Ken Thompson", detail = "Unix and UTF-8" },
    { name = "Margaret Hamilton", detail = "Apollo guidance software" },
}

M.query = state("m3_query", "")
local removed = state("m3_removed", {})
local added = state("m3_added", {})

-- Everyone in name order: the starting contacts plus those saved from the form.
local everyone = added:map(function(extra)
    local people = { table.unpack(CONTACTS) }
    for _, person in ipairs(extra or {}) do
        people[#people + 1] = person
    end
    table.sort(people, function(a, b) return a.name < b.name end)
    return people
end)

M.shown = computed({ M.query, removed, everyone }, function(q, gone, people_in_order)
    local hits = {}
    for i, person in ipairs(people_in_order) do
        local score = not (gone or {})[person.name] and fuzzy(person.name .. " " .. person.detail, q or "")
        if score then
            hits[#hits + 1] = { person = person, score = score, index = i }
        end
    end
    -- Best match first; ties keep the alphabetical order (`table.sort` is not stable).
    table.sort(hits, function(a, b)
        if a.score ~= b.score then
            return a.score > b.score
        end
        return a.index < b.index
    end)
    local people = {}
    for i, hit in ipairs(hits) do
        people[i] = hit.person
    end
    return people
end)

function M.remove(person)
    overlay.ask({ icon = "delete", title = "Delete contact?", body = person.name .. " will be removed from your contacts.", confirm = "Delete" }, function()
        local gone = {}
        for k, v in pairs(removed:get() or {}) do
            gone[k] = v
        end
        gone[person.name] = true
        removed:set(gone)
        overlay.notify(person.name .. " deleted", {
            action = "Undo",
            on_action = function()
                local back = {}
                for k, v in pairs(removed:get() or {}) do
                    back[k] = k ~= person.name and v or nil
                end
                removed:set(back)
            end,
        })
    end)
end

function M.restore()
    removed:set({})
    added:set({})
end

function M.is_email(text)
    return not text:match("^[^@%s]+@[^@%s]+%.[^@%s]+$") and "Enter an address like name@example.com" or nil
end

-- Adds a person (the note, else the email, as its second line); a missing name, a bad address or a
-- name already listed returns the reason instead.
function M.add(name, email, note)
    name = (name or ""):match("^%s*(.-)%s*$")
    email, note = email or "", note or ""
    if name == "" then
        return "Enter a name to save"
    elseif email ~= "" and M.is_email(email) then
        return "Fix the email address first"
    end
    for _, person in ipairs(everyone:get()) do
        if person.name == name then
            return name .. " is already in Contacts"
        end
    end
    local extra = { table.unpack(added:get() or {}) }
    extra[#extra + 1] = { name = name, detail = note ~= "" and note or email ~= "" and email or "New contact" }
    added:set(extra)
    -- A saved name deleted earlier comes back.
    local gone = {}
    for k, v in pairs(removed:get() or {}) do
        gone[k] = k ~= name and v or nil
    end
    removed:set(gone)
end

return M
