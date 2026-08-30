import { MigrationInterface, QueryRunner } from "typeorm";

export class InitialSchema1787788800000 implements MigrationInterface {
  name = "InitialSchema1787788800000";

  public async up(q: QueryRunner): Promise<void> {
    await q.query(
      "CREATE TABLE `category` (`id` int NOT NULL AUTO_INCREMENT, `name` varchar(255) NOT NULL, PRIMARY KEY (`id`)) ENGINE=InnoDB",
    );
    await q.query(
      "CREATE TABLE `post` (`id` int NOT NULL AUTO_INCREMENT, `title` varchar(255) NOT NULL, `text` text NOT NULL, PRIMARY KEY (`id`)) ENGINE=InnoDB",
    );
    await q.query(
      "CREATE TABLE `post_categories_category` (`postId` int NOT NULL, `categoryId` int NOT NULL, INDEX `IDX_post_categories_post` (`postId`), INDEX `IDX_post_categories_category` (`categoryId`), PRIMARY KEY (`postId`, `categoryId`)) ENGINE=InnoDB",
    );
    await q.query(
      "ALTER TABLE `post_categories_category` ADD CONSTRAINT `FK_post_categories_post` FOREIGN KEY (`postId`) REFERENCES `post`(`id`) ON DELETE CASCADE ON UPDATE CASCADE",
    );
    await q.query(
      "ALTER TABLE `post_categories_category` ADD CONSTRAINT `FK_post_categories_category` FOREIGN KEY (`categoryId`) REFERENCES `category`(`id`) ON DELETE CASCADE ON UPDATE CASCADE",
    );
  }

  public async down(q: QueryRunner): Promise<void> {
    await q.query("DROP TABLE `post_categories_category`");
    await q.query("DROP TABLE `post`");
    await q.query("DROP TABLE `category`");
  }
}
