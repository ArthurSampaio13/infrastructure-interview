import "reflect-metadata";
import { DataSource } from "typeorm";
import { config } from "./config";
import { Post } from "./entity/Post";
import { Category } from "./entity/Category";
import { InitialSchema1787788800000 } from "./migration/1787788800000-InitialSchema";

export const dataSource = new DataSource({
  type: "mysql",
  host: config.DB_HOST,
  port: config.DB_PORT,
  username: config.DB_USER,
  password: config.DB_PASSWORD,
  database: config.DB_NAME,
  entities: [Post, Category],
  migrations: [InitialSchema1787788800000],
  synchronize: false,
  logging: false,
  connectTimeout: 10_000,
  extra: { connectionLimit: 10 },
});
