import {readdir, readFile, writeFile} from 'fs/promises';
import {existsSync} from 'fs';
import {printHeader, COLOR, printFooter, luaPreProcessorLogger, luaExpressionHandler} from './logging.js';
import {createRequire} from 'module';
import {bundle} from 'luabundle'

const require = createRequire(import.meta.url);

// load default bundler settings
console.log(`Parsing default bundler settings...`)
const defaultBundlerSettings = require('./bundle.default.json');

// detect all projects
const basePath = process.argv[2];
const sourceDir = await readdir(`${basePath}/src`, {withFileTypes: true});
const availableProjects = sourceDir
    .filter(item => item.isDirectory())
    .filter(directory => existsSync(`${directory.path}/${directory.name}/bundle.json`))
    .map(directory => {
        return {
            name: `${directory.name}`,
            path: `${directory.path}/${directory.name}`,
        }
    });

// filter projects
const projectFilter = process.argv[3] ?? "";
const activeProjects = availableProjects.filter(project => (projectFilter.length !== 0) ? project.name.toLocaleLowerCase() === projectFilter.toLocaleLowerCase() : true);
console.log(`Selected ${activeProjects.length} of ${availableProjects.length} available project(s).`);

// start building the projects
for (let project of activeProjects) {
    const startTime = performance.now();
    printHeader(
        project.name, COLOR.cyan,
        `Source: ${project.path}`
    );

    try {
        // read project configs
        console.log(`Parsing bundle.json`)
        const bundleFile = await readFile(`${project.path}/bundle.json`)
        const projectSettings = {
            ...defaultBundlerSettings,
            ...JSON.parse(bundleFile.toString())
        };
        
        // specify root file
        const rootFile = `${project.path}/${projectSettings.main}`
        
        // create bundler settings
        const bundleOptions = {
            force: projectSettings.force,
            isolate: projectSettings.isolate,
            luaVersion: projectSettings.luaVersion,
            metadata: projectSettings.metadata,
            rootModuleName: projectSettings.rootModuleName,
            paths: projectSettings["imports"].map(i => `${project.path}/${i}`),
        };

        // convert multiple lua files into one
        console.log(`Bundling ${rootFile}`)
        const bundledLua = bundle(rootFile, {
            ...bundleOptions,
            preprocess: (module) => luaPreProcessorLogger(module, bundleOptions, rootFile),
            expressionHandler: luaExpressionHandler
        });

        // write to output file
        const outputFile= `${basePath}/dist/${project.name}.lua`;
        console.log(`Writing results to ${outputFile}`)
        await writeFile(outputFile, bundledLua);

        // report results
        printFooter(
            `BUILD SUCCESS`, COLOR.brightGreen,
            `Total time:`.padEnd(13) + `${(performance.now() - startTime).toFixed(3)} s\n` +
            `Finished at:`.padEnd(13) + `${new Date().toISOString()}`
        );
    } catch (e) {
        console.log(`${COLOR.red}${e.message}${COLOR.reset}`)

        if (e.cause) {
            console.log(`${COLOR.red}Possible cause: ${e.cause}${COLOR.reset}`)
        }

        // report results
        printFooter(
            `BUILD FAILED`, COLOR.red,
            `Total time:`.padEnd(13) + `${(performance.now() - startTime).toFixed(3)} s\n` +
            `Finished at:`.padEnd(13) + `${new Date().toISOString()}`
        );
    }
}