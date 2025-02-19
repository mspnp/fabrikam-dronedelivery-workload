// ------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License (MIT). See License.txt in the repo root for license information.
// ------------------------------------------------------------

import { MongoErrors } from './util/mongo-err.js'

import appInsights from "applicationinsights";
import { MongoClient } from "mongodb";

export class PackageServiceInitializer
{
    static async initialize(connection: string, collectionName: string, containerName: string) {
        try {
            PackageServiceInitializer.initAppInsights(containerName);
            await PackageServiceInitializer.initMongoDb(connection,
                                                        collectionName);
        }
        catch(ex) {
            console.log(ex);
        }
    }

    private static async initMongoDb(connection: string, collectionName: string) {
        try {
            var db = (await MongoClient.connect(connection)).db();
            await db.command({customAction: "CreateCollection", collection: db.databaseName + '.' + collectionName});
        }
        catch (ex: any) {
            if (ex.code != MongoErrors.CommandNotFound && ex.code != 9) {
                console.log(ex);
            }
        }
    }

    private static initAppInsights(cloudRole = "package") {
        if (!process.env.APPINSIGHTS_CONNECTION_STRING &&
                process.env.NODE_ENV === 'development') {
            const logger = console;
            process.stderr.write('Skipping app insights setup - in development mode with no application insights connection string set\n');
        } else if (process.env.APPINSIGHTS_CONNECTION_STRING) {
            appInsights.setup(process.env.APPINSIGHTS_CONNECTION_STRING!);
            appInsights.defaultClient.context.tags[appInsights.defaultClient.context.keys.cloudRole] = cloudRole;
            process.stdout.write('App insights setup - configuring client\n');
            appInsights.start();
            process.stdout.write('Application Insights started');
        } else {
            throw new Error('No app insights setup. A key must be specified in non-development environments.');
        }
    }
}
