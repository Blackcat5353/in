//
//  DrawTask.cpp
//  render/src/render
//
//  Created by Sam Gateau on 5/21/15.
//  Copyright 20154 High Fidelity, Inc.
//
//  Distributed under the Apache License, Version 2.0.
//  See the accompanying file LICENSE or http://www.apache.org/licenses/LICENSE-2.0.html
//

#include "DrawTask.h"

#include <algorithm>
#include <assert.h>

#include <PerfStat.h>
#include <ViewFrustum.h>
#include <gpu/Context.h>

using namespace render;

void render::renderItems(const SceneContextPointer& sceneContext, const RenderContextPointer& renderContext, const ItemBounds& inItems) {
    auto& scene = sceneContext->_scene;
    RenderArgs* args = renderContext->args;

    for (const auto& itemDetails : inItems) {
        auto& item = scene->getItem(itemDetails.id);
        item.render(args);
    }
}

void renderShape(RenderArgs* args, const ShapePlumberPointer& shapeContext, const Item& item) {
    assert(item.getKey().isShape());
    const auto& key = item.getShapeKey();
    if (key.isValid() && !key.hasOwnPipeline()) {
        args->_pipeline = shapeContext->pickPipeline(args, key);
        if (args->_pipeline) {
            item.render(args);
        }
        args->_pipeline = nullptr;
    } else if (key.hasOwnPipeline()) {
        item.render(args);
    } else {
        qDebug() << "Item could not be rendered: invalid key ?" << key;
    }
}

void render::renderShapes(const SceneContextPointer& sceneContext, const RenderContextPointer& renderContext,
                          const ShapePlumberPointer& shapeContext, const ItemBounds& inItems, int maxDrawnItems) {
    auto& scene = sceneContext->_scene;
    RenderArgs* args = renderContext->args;
    
    int numItemsToDraw = (int)inItems.size();
    if (maxDrawnItems != -1) {
        numItemsToDraw = glm::min(numItemsToDraw, maxDrawnItems);
    }
    for (auto i = 0; i < numItemsToDraw; ++i) {
        auto& item = scene->getItem(inItems[i].id);
        renderShape(args, shapeContext, item);
    }
}

void DrawLight::run(const SceneContextPointer& sceneContext, const RenderContextPointer& renderContext) {
    assert(renderContext->args);
    assert(renderContext->args->_viewFrustum);

    // render lights
    auto& scene = sceneContext->_scene;
    auto& items = scene->getMasterBucket().at(ItemFilter::Builder::light());

    ItemBounds inItems;
    inItems.reserve(items.size());
    for (auto id : items) {
        auto item = scene->getItem(id);
        inItems.emplace_back(ItemBound(id, item.getBound()));
    }

    RenderArgs* args = renderContext->args;

    auto& details = args->_details.edit(RenderDetails::OTHER_ITEM);
    ItemBounds culledItems;
    culledItems.reserve(inItems.size());
    cullItems(renderContext, _cullFunctor, details, inItems, culledItems);

    gpu::doInBatch(args->_context, [&](gpu::Batch& batch) {
        args->_batch = &batch;
        renderItems(sceneContext, renderContext, culledItems);
        args->_batch = nullptr;
    });
}

void PipelineSortShapes::run(const SceneContextPointer& sceneContext, const RenderContextPointer& renderContext, const ItemBounds& inItems, ShapesIDsBounds& outShapes) {
    auto& scene = sceneContext->_scene;
    outShapes.clear();

    for (const auto& item : inItems) {
        auto key = scene->getItem(item.id).getShapeKey();
        auto outItems = outShapes.find(key);
        if (outItems == outShapes.end()) {
            outItems = outShapes.insert(std::make_pair(key, ItemBounds{})).first;
            outItems->second.reserve(inItems.size());
        }

        outItems->second.push_back(item);
    }

    for (auto& items : outShapes) {
        items.second.shrink_to_fit();
    }
}

void DepthSortShapes::run(const SceneContextPointer& sceneContext, const RenderContextPointer& renderContext, const ShapesIDsBounds& inShapes, ShapesIDsBounds& outShapes) {
    outShapes.clear();
    outShapes.reserve(inShapes.size());

    for (auto& pipeline : inShapes) {
        auto& inItems = pipeline.second;
        auto outItems = outShapes.find(pipeline.first);
        if (outItems == outShapes.end()) {
            outItems = outShapes.insert(std::make_pair(pipeline.first, ItemBounds{})).first;
        }

        depthSortItems(sceneContext, renderContext, _frontToBack, inItems, outItems->second);
    }
}
