
export type Context<T> = {
    modules: { (T) -> ()},
    props: T,
    spawn: boolean?,
}
return function<T>(context: Context<T>)
    if context.spawn then
        task.spawn(function()
            for _, module in context.modules do
                module(context.props)
            end
        end)
    else
        for _, module in context.modules do
            module(context.props)
        end
    end

    return true
end