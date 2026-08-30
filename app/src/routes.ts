import { NextFunction, Request, Response, Router } from "express";
import { z } from "zod";
import { dataSource } from "./data-source";
import { Post } from "./entity/Post";

const postSchema = z.object({
  title: z.string().min(1).max(255),
  text: z.string().min(1),
  categories: z.array(z.object({ name: z.string().min(1).max(255) })).optional(),
});

type Handler = (req: Request, res: Response) => Promise<unknown>;
const wrap =
  (fn: Handler) => (req: Request, res: Response, next: NextFunction) =>
    fn(req, res).catch(next);

const repo = () => dataSource.getRepository(Post);

export const router = Router();

router.get(
  "/posts",
  wrap(async (_req, res) => {
    res.json(await repo().find({ relations: { categories: true } }));
  }),
);

router.get(
  "/posts/:id",
  wrap(async (req, res) => {
    const id = Number(req.params.id);
    if (!Number.isInteger(id) || id < 1) return res.status(400).json({ error: "invalid id" });
    const post = await repo().findOne({ where: { id }, relations: { categories: true } });
    if (!post) return res.status(404).json({ error: "not found" });
    res.json(post);
  }),
);

router.post(
  "/posts",
  wrap(async (req, res) => {
    const body = postSchema.safeParse(req.body);
    if (!body.success) {
      return res.status(400).json({ error: "invalid body", details: body.error.flatten().fieldErrors });
    }
    const post = repo().create(body.data);
    res.status(201).json(await repo().save(post));
  }),
);
