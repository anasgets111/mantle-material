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

-- Everyone not deleted, in name order; the list filters it by `M.query`.
M.shown = computed({ removed, everyone }, function(gone, people)
    local kept = {}
    for _, person in ipairs(people) do
        if not (gone or {})[person.name] then
            kept[#kept + 1] = person
        end
    end
    return kept
end)

-- The deleted set without `key`.
local function without(key)
    local gone = {}
    for k, v in pairs(removed:get() or {}) do
        gone[k] = k ~= key and v or nil
    end
    return gone
end

function M.remove(person)
    overlay.confirm_remove({ title = "Delete contact?", message = person.name .. " will be removed from your contacts.", removed = person.name .. " deleted" }, function()
        local gone = without()
        gone[person.name] = true
        removed:set(gone)
    end, function() removed:set(without(person.name)) end)
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
    removed:set(without(name)) -- a saved name deleted earlier comes back
end

return M
