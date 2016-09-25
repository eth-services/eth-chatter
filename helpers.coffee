
exports.buildRedirect = (query, transaction_data) ->
    if query.redirect
        redirect_url = query.redirect

        regex = /\[(.*?)\]/

        matchAndInject = (redirect_url) ->

            matched = regex.exec(redirect_url)
            if matched?
                injector = matched[1]
                key = injector.replace('t.','')

                redirect_url = redirect_url[0..(matched.index - 1)] + transaction_data[key] + redirect_url[(matched.index + matched[1].length + 2)..]
                matched = regex.exec(redirect_url)

                if matched?
                    matchAndInject redirect_url
                else
                    return redirect_url

        redirect_url = matchAndInject redirect_url

    else return null