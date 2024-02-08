export function printSeperator(text = "", textColor = COLOR.reset, length = 72, startBracket = "<", endBracket = ">") {
    const textLength = text.length === 0 ? 0 : `${startBracket} ${text} ${endBracket}`.length;
    const seperatorLength = (length / 2).toFixed() - (textLength / 2).toFixed();
    process.stdout.write(COLOR.reset + '-'.repeat(seperatorLength));

    if (textLength !== 0)
        process.stdout.write(`${COLOR.reset}${startBracket} ${textColor}${text} ${COLOR.reset}${endBracket}`);
    
    if (seperatorLength * 2 < length)
        process.stdout.write(COLOR.reset + '-');

    process.stdout.write(COLOR.reset + '-'.repeat(seperatorLength));
    process.stdout.write(COLOR.reset + '\n');
}

export function printHeader(title, titleColor = COLOR.reset, body = "", bodyColor = COLOR.reset, length = 72) {
    process.stdout.write('\n');
    printSeperator(title, titleColor, length);

    if (body.length !== 0) {
        process.stdout.write(`${bodyColor}${body}\n`);
        printSeperator("", COLOR.reset, length);
    }
}

export function printFooter(title, titleColor = COLOR.reset, body = "", bodyColor = COLOR.reset, length = 72) {
    printSeperator("", COLOR.reset, length);
    process.stdout.write(`${titleColor}${title}\n`);
    printSeperator("", COLOR.reset, length);
    
    if (body.length !== 0) {
        process.stdout.write(`${bodyColor}${body}\n`);
        printSeperator("", COLOR.reset, length);
    }
}

export function luaPreProcessorLogger(module, settings, rootFilePath) {
    if (module.name === settings.rootModuleName)
        console.log(`Resolved module ${module.name} to ${rootFilePath}`);
    else if (module.resolvedPath)
        console.log(`Resolved module ${module.name} to ${module.resolvedPath}`);
    else if (!settings.force)
        console.log(`Failed to resolved module ${module.name}. Falling back to require().`);
    else
        console.log(`Failed to resolved module ${module.name}. Not falling back to require() as "isolate" is enabled.`);

    return module.content;
}

export function luaExpressionHandler(module, expression) {
    const start = expression.loc.start;
    
    process.stdout.write(COLOR.yellow);
    process.stdout.write(`Warning: Non-literal require found in '${module.name}' at ${start.line}:${start.column}. Do not use variables as require names!\n`);
    process.stdout.write(`This import will be ignores and may break your script!${COLOR.reset}\n`);
}

export const COLOR = {
    reset: `\u001b[0m`, black: `\u001b[30m`,
    red: `\u001b[31m`, green: `\u001b[32m`,
    yellow: `\u001b[33m`, blue: `\u001b[34m`,
    magenta: `\u001b[35m`, cyan: `\u001b[36m`,
    white: `\u001b[37m`, gray: `\u001b[90m`,
    grey: `\u001b[90m`, brightRed: `\u001b[91m`,
    brightGreen: `\u001b[92m`, brightYellow: `\u001b[93m`,
    brightBlue: `\u001b[94m`, brightMagenta: `\u001b[95m`,
    brightCyan: `\u001b[96m`, brightWhite: `\u001b[97m`,
}