local pairs = pairs
local string_len = string.len
local judge_util = require("orange.utils.judge")
local BasePlugin = require("orange.plugins.base")


local RewriteHandler = BasePlugin:extend()
RewriteHandler.PRIORITY = 2000

function RewriteHandler:new(store)
    RewriteHandler.super.new(self, "rewrite-plugin")
    self.store = store
end

function RewriteHandler:rewrite(conf)
    RewriteHandler.super.rewrite(self)
    local rewrite_config = self.store:get_rewrite_config()
    if rewrite_config.enable ~= true then
        return
    end

    local rewrite_rules = rewrite_config.rewrite_rules

    local ngx_var_uri = ngx.var.uri
    local ngx_set_uri = ngx.req.set_uri
    local ngx_re_gsub = ngx.re.gsub

    for i, rule in pairs(rewrite_rules) do
        local enable = rule.enable
        if enable == true then
            local judge = rule.judge
            local match_type = judge.type
            local conditions = judge.conditions
            local pass = false
            if match_type == 0 or match_type == 1 then
                pass = judge_util.filter_and_conditions(conditions)
            elseif match_type == 2 then
                pass = judge_util.filter_or_conditions(conditions)
            elseif match_type == 3 then
                pass = judge_util.filter_complicated_conditions(judge.expression, conditions, self:get_name())
            end

            if pass then
                local handle = rule.handle

                if handle and handle.rewrite_to then
                    local new_uri
                    local replace_re = handle.regrex
                    if replace_re and replace_re ~= "" then
                        new_uri = ngx_re_gsub(ngx_var_uri, replace_re, handle.rewrite_to)
                    else
                        new_uri = handle.rewrite_to
                    end

                    if new_uri ~= ngx_var_uri then
                        if handle.log == true then
                            ngx.log(ngx.ERR, "[Rewrite] ", ngx_var_uri, " to:",  new_uri)
                        end
                        ngx_set_uri(new_uri, true)
                    end

                    return
                end
            end
        end
    end
end

return RewriteHandler